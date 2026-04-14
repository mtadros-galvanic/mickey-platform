#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_FILE="${SECRETS_FILE:-$ROOT/secrets/prod.sops.yaml}"
PROXMOX_NODE_NAME="${PROXMOX_NODE_NAME:-pve}"
PROXMOX_BRIDGE="${PROXMOX_BRIDGE:-vmbr0}"
IMPORT_DATASTORE_ID="${IMPORT_DATASTORE_ID:-local}"
VM_DISK_DATASTORE_ID="${VM_DISK_DATASTORE_ID:-local-lvm}"
CLOUD_INIT_DATASTORE_ID="${CLOUD_INIT_DATASTORE_ID:-local-lvm}"
TEMPLATE_MEMORY_MB="${TEMPLATE_MEMORY_MB:-4096}"
TEMPLATE_CORES="${TEMPLATE_CORES:-2}"
VM_ADMIN_USER="${VM_ADMIN_USER:-galvanic}"
FORCE_REBUILD="${FORCE_REBUILD:-0}"

: "${TEMPLATE_ID:?set TEMPLATE_ID}"
: "${TEMPLATE_NAME:?set TEMPLATE_NAME}"
: "${UBUNTU_CLOUD_IMAGE_URL:?set UBUNTU_CLOUD_IMAGE_URL}"
CLOUD_IMAGE_FILE_NAME="${CLOUD_IMAGE_FILE_NAME:-$(basename "$UBUNTU_CLOUD_IMAGE_URL")}"

for tool in terraform sops python3 jq curl; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "missing required tool: $tool" >&2
    exit 1
  fi
done

tmpdir="$(mktemp -d)"
tmpyaml="$(mktemp)"
tmpjson="$(mktemp --suffix=.tfvars.json)"
tmpresp="$(mktemp)"
cleanup() {
  rm -rf "$tmpdir" "$tmpyaml" "$tmpjson" "$tmpresp"
}
trap cleanup EXIT

sops -d "$SECRETS_FILE" > "$tmpyaml"
python3 "$ROOT/scripts/render_tfvars.py" "$tmpyaml" | jq '{proxmox_api_url, proxmox_api_token, proxmox_tls_insecure, ssh_public_keys}' > "$tmpjson"

api_url="$(jq -r '.proxmox_api_url' "$tmpjson" | sed 's#/api2/json$##')"
api_token="$(jq -r '.proxmox_api_token' "$tmpjson")"
auth_header="Authorization: PVEAPIToken=$api_token"
config_url="$api_url/api2/json/nodes/$PROXMOX_NODE_NAME/qemu/$TEMPLATE_ID/config"

http_code="$(curl -sk -o "$tmpresp" -w '%{http_code}' -H "$auth_header" "$config_url")"
if [[ "$http_code" == "200" ]]; then
  existing_name="$(jq -r '.data.name // empty' "$tmpresp")"
  existing_template="$(jq -r '.data.template // 0' "$tmpresp")"

  if [[ "$FORCE_REBUILD" != "1" && "$existing_name" == "$TEMPLATE_NAME" && "$existing_template" == "1" ]]; then
    echo "template already exists: $TEMPLATE_NAME ($TEMPLATE_ID)"
    exit 0
  fi

  echo "template VMID $TEMPLATE_ID already exists and FORCE_REBUILD is not implemented in the API builder" >&2
  exit 1
fi

cat > "$tmpdir/main.tf" <<EOF
terraform {
  required_version = "~> 1.8"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.94.0"
    }
  }
}

variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_tls_insecure" {
  type = bool
}

variable "ssh_public_keys" {
  type    = list(string)
  default = []
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_tls_insecure
}

resource "proxmox_virtual_environment_download_file" "cloud_image" {
  content_type        = "import"
  datastore_id        = "${IMPORT_DATASTORE_ID}"
  node_name           = "${PROXMOX_NODE_NAME}"
  file_name           = "${CLOUD_IMAGE_FILE_NAME}"
  url                 = "${UBUNTU_CLOUD_IMAGE_URL}"
  overwrite           = true
  overwrite_unmanaged = true
  upload_timeout      = 1800
  verify              = true
}

resource "proxmox_virtual_environment_vm" "template" {
  name          = "${TEMPLATE_NAME}"
  node_name     = "${PROXMOX_NODE_NAME}"
  vm_id         = ${TEMPLATE_ID}
  template      = true
  started       = false
  on_boot       = false
  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"

  agent {
    enabled = true
  }

  cpu {
    cores = ${TEMPLATE_CORES}
    type  = "host"
  }

  memory {
    dedicated = ${TEMPLATE_MEMORY_MB}
  }

  efi_disk {
    datastore_id      = "${VM_DISK_DATASTORE_ID}"
    type              = "4m"
    pre_enrolled_keys = true
  }

  disk {
    datastore_id = "${VM_DISK_DATASTORE_ID}"
    interface    = "scsi0"
    import_from  = proxmox_virtual_environment_download_file.cloud_image.id
    discard      = "on"
    ssd          = true
  }

  initialization {
    datastore_id = "${CLOUD_INIT_DATASTORE_ID}"
    interface    = "ide2"

    user_account {
      username = "${VM_ADMIN_USER}"
      keys     = var.ssh_public_keys
    }

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  network_device {
    bridge   = "${PROXMOX_BRIDGE}"
    firewall = false
    model    = "virtio"
  }
}
EOF

terraform -chdir="$tmpdir" init >/dev/null
terraform -chdir="$tmpdir" apply -auto-approve -var-file="$tmpjson"
