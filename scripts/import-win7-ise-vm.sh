#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_FILE="${SECRETS_FILE:-$ROOT/secrets/prod.sops.yaml}"
PROXMOX_NODE_NAME="${PROXMOX_NODE_NAME:-pve}"
IMPORT_DATASTORE_ID="${IMPORT_DATASTORE_ID:-local}"
VM_DISK_DATASTORE_ID="${VM_DISK_DATASTORE_ID:-bulk}"
PROXMOX_BRIDGE="${PROXMOX_BRIDGE:-vmbr0}"
VMWARE_SOURCE_DIR="${VMWARE_SOURCE_DIR:-/home/mtadros/vm}"
SOURCE_DESCRIPTOR="${SOURCE_DESCRIPTOR:-Win7-000002.vmdk}"
QCOW_CACHE_DIR="${QCOW_CACHE_DIR:-$HOME/.cache/mickey-ise7}"
QCOW_OUTPUT_NAME="${QCOW_OUTPUT_NAME:-Win7-current.qcow2}"
IMPORT_FILE_NAME="${IMPORT_FILE_NAME:-mickey-ise7-current.qcow2}"
VM_ID="${VM_ID:-703}"
VM_NAME="${VM_NAME:-mickey-ise7}"
VM_MEMORY_MB="${VM_MEMORY_MB:-8192}"
VM_CORES="${VM_CORES:-4}"
VM_NET_MODEL="${VM_NET_MODEL:-e1000}"
VM_SCSI_HW="${VM_SCSI_HW:-lsi}"
VM_BIOS="${VM_BIOS:-seabios}"
VM_MACHINE="${VM_MACHINE:-pc-i440fx-10.1}"
VM_DISK_SIZE_GB="${VM_DISK_SIZE_GB:-}"
FORCE_REBUILD="${FORCE_REBUILD:-0}"
START_VM="${START_VM:-1}"
DRY_RUN="${DRY_RUN:-0}"

usage() {
  cat <<'USAGE'
usage: import-win7-ise-vm.sh [--dry-run] [--force] [--no-start]

Imports the current VMware-backed Windows 7 guest into Proxmox as `mickey-ise7`.

Workflow:
  1. Resolve the active VMware VMDK chain locally.
  2. Convert that chain into one qcow2 with qemu-img.
  3. Upload the qcow2 to Proxmox `local:import` through the API.
  4. Import the uploaded disk into a Proxmox VM on `bulk`.

Environment overrides:
  SECRETS_FILE         SOPS file containing the Proxmox API token
  PROXMOX_NODE_NAME    Proxmox node name
  IMPORT_DATASTORE_ID  Proxmox datastore for uploaded import files
  VM_DISK_DATASTORE_ID Proxmox datastore for the imported VM disk
  PROXMOX_BRIDGE       Bridge name for the guest NIC
  VMWARE_SOURCE_DIR    Local directory containing the VMware VM
  SOURCE_DESCRIPTOR    Child VMDK descriptor to import
  QCOW_CACHE_DIR       Local cache directory for the converted qcow2
  QCOW_OUTPUT_NAME     Local qcow2 file name
  IMPORT_FILE_NAME     Imported qcow2 file name in Proxmox `local:import`
  VM_ID                Proxmox VMID to create
  VM_NAME              Proxmox VM name to create
  VM_MEMORY_MB         Guest memory in MiB
  VM_CORES             Guest vCPU count
  VM_NET_MODEL         Guest NIC model, defaults to e1000 for Windows 7
  VM_SCSI_HW           Proxmox SCSI controller model, defaults to lsi
  VM_BIOS              Guest firmware, defaults to seabios
  VM_MACHINE           Machine type, defaults to pc-i440fx-10.1
  VM_DISK_SIZE_GB      Imported disk size in GiB; defaults to the source image size
  FORCE_REBUILD        Reserved for future use; current importer refuses to destroy an existing VM
  START_VM             1 to boot the VM immediately after import, 0 to leave it stopped
  DRY_RUN              1 to resolve the chain and show the planned values without Proxmox changes
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --force)
      FORCE_REBUILD=1
      shift
      ;;
    --no-start)
      START_VM=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

for tool in python3 qemu-img; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "missing required tool: $tool" >&2
    exit 1
  fi
done

descriptor_path="$VMWARE_SOURCE_DIR/$SOURCE_DESCRIPTOR"
if [[ ! -f "$descriptor_path" ]]; then
  echo "source descriptor not found: $descriptor_path" >&2
  exit 1
fi

files_list="$(mktemp)"
chain_list="$(mktemp)"
tmpdir=""
tmpyaml=""
tmpjson=""
tmpresp=""
cleanup() {
  rm -f "$files_list" "$chain_list"

  if [[ -n "$tmpyaml" ]]; then
    rm -f "$tmpyaml"
  fi

  if [[ -n "$tmpjson" ]]; then
    rm -f "$tmpjson"
  fi

  if [[ -n "$tmpresp" ]]; then
    rm -f "$tmpresp"
  fi

  if [[ -n "$tmpdir" ]]; then
    rm -rf "$tmpdir"
  fi
}
trap cleanup EXIT

python3 "$ROOT/scripts/resolve_vmware_vmdk_chain.py" --list "$descriptor_path" > "$files_list"
python3 "$ROOT/scripts/resolve_vmware_vmdk_chain.py" --chain "$descriptor_path" > "$chain_list"

virtual_size_bytes="$({
  qemu-img info --output=json "$descriptor_path" |
    python3 -c 'import json, sys; print(json.load(sys.stdin)["virtual-size"])'
})"

if [[ -z "$VM_DISK_SIZE_GB" ]]; then
  VM_DISK_SIZE_GB="$({
    python3 - "$virtual_size_bytes" <<'PYBLOCK'
import math
import sys

print(math.ceil(int(sys.argv[1]) / (1024 ** 3)))
PYBLOCK
  })"
fi

mkdir -p "$QCOW_CACHE_DIR"
qcow_path="$QCOW_CACHE_DIR/$QCOW_OUTPUT_NAME"

echo "source descriptor: $SOURCE_DESCRIPTOR"
echo "descriptor chain:"
sed 's/^/  - /' "$chain_list"
echo "required file count: $(wc -l < "$files_list" | tr -d ' ')"
echo "local qcow cache: $qcow_path"
echo "proxmox import file: ${IMPORT_DATASTORE_ID}:import/$IMPORT_FILE_NAME"
echo "target VM: $VM_NAME ($VM_ID)"
echo "disk datastore: $VM_DISK_DATASTORE_ID"
echo "resolved disk size: ${VM_DISK_SIZE_GB} GiB"

if [[ "$DRY_RUN" == "1" ]]; then
  echo
  echo "dry run only; no qcow2 conversion, upload, or Proxmox changes made"
  exit 0
fi

for tool in terraform sops jq curl; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "missing required tool: $tool" >&2
    exit 1
  fi
done

tmpdir="$(mktemp -d)"
tmpyaml="$(mktemp)"
tmpjson="$(mktemp --suffix=.tfvars.json)"
tmpresp="$(mktemp)"

sops -d "$SECRETS_FILE" > "$tmpyaml"
python3 "$ROOT/scripts/render_tfvars.py" "$tmpyaml" | jq '{proxmox_api_url, proxmox_api_token, proxmox_tls_insecure}' > "$tmpjson"

api_url="$(jq -r '.proxmox_api_url' "$tmpjson" | sed 's#/api2/json$##')"
api_token="$(jq -r '.proxmox_api_token' "$tmpjson")"
auth_header="Authorization: PVEAPIToken=$api_token"
config_url="$api_url/api2/json/nodes/$PROXMOX_NODE_NAME/qemu/$VM_ID/config"

http_code="$(curl -sk -o "$tmpresp" -w '%{http_code}' -H "$auth_header" "$config_url")"
case "$http_code" in
  200)
    existing_name="$(jq -r '.data.name // empty' "$tmpresp")"
    if [[ "$existing_name" == "$VM_NAME" ]]; then
      echo "VM already exists: $VM_NAME ($VM_ID)"
      exit 0
    fi

    if [[ "$FORCE_REBUILD" == "1" ]]; then
      echo "VMID $VM_ID is already in use by '$existing_name'. FORCE_REBUILD is not implemented for the API importer; destroy the VM first or choose a new VM_ID." >&2
      exit 1
    fi

    echo "VMID $VM_ID is already in use by '$existing_name'." >&2
    exit 1
    ;;
  404)
    ;;
  *)
    echo "failed to query Proxmox for VMID $VM_ID (HTTP $http_code)" >&2
    cat "$tmpresp" >&2
    exit 1
    ;;
esac

# VMware split VMDKs cannot be uploaded directly through the Proxmox file API.
# Convert the resolved chain locally into one qcow2 first, then import that file.
rm -f "$qcow_path"
qemu-img convert -p -c -O qcow2 "$descriptor_path" "$qcow_path"

echo
echo "converted qcow2:"
qemu-img info "$qcow_path"

if [[ "$START_VM" == "1" ]]; then
  tf_started="true"
else
  tf_started="false"
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

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_tls_insecure
}

resource "proxmox_virtual_environment_file" "disk_image" {
  content_type   = "import"
  datastore_id   = "${IMPORT_DATASTORE_ID}"
  node_name      = "${PROXMOX_NODE_NAME}"
  overwrite      = true
  timeout_upload = 7200

  source_file {
    path      = "${qcow_path}"
    file_name = "${IMPORT_FILE_NAME}"
  }
}

resource "proxmox_virtual_environment_vm" "mickey_ise7" {
  name          = "${VM_NAME}"
  node_name     = "${PROXMOX_NODE_NAME}"
  vm_id         = ${VM_ID}
  started       = ${tf_started}
  on_boot       = false
  bios          = "${VM_BIOS}"
  machine       = "${VM_MACHINE}"
  scsi_hardware = "${VM_SCSI_HW}"
  boot_order    = ["scsi0"]

  delete_unreferenced_disks_on_destroy = true
  purge_on_destroy                     = true
  stop_on_destroy                      = true
  timeout_create                       = 7200
  timeout_start_vm                     = 600
  timeout_stop_vm                      = 600
  tablet_device                        = false
  tags                                 = ["manual", "legacy", "windows-7", "xilinx", "mickey"]

  operating_system {
    type = "win7"
  }

  agent {
    enabled = false
  }

  cpu {
    cores = ${VM_CORES}
    type  = "host"
  }

  memory {
    dedicated = ${VM_MEMORY_MB}
  }

  disk {
    datastore_id = "${VM_DISK_DATASTORE_ID}"
    interface    = "scsi0"
    import_from  = proxmox_virtual_environment_file.disk_image.id
    size         = ${VM_DISK_SIZE_GB}
    backup       = true
  }

  network_device {
    bridge   = "${PROXMOX_BRIDGE}"
    firewall = false
    model    = "${VM_NET_MODEL}"
  }
}
EOF

terraform -chdir="$tmpdir" init >/dev/null
terraform -chdir="$tmpdir" apply -auto-approve -var-file="$tmpjson"

status_url="$api_url/api2/json/nodes/$PROXMOX_NODE_NAME/qemu/$VM_ID/status/current"
status_code="$(curl -sk -o "$tmpresp" -w '%{http_code}' -H "$auth_header" "$status_url")"
if [[ "$status_code" == "200" ]]; then
  echo
  echo "current VM status:"
  jq -r '.data | "  name: \(.name)\n  status: \(.status)\n  qmpstatus: \(.qmpstatus)\n  maxdisk: \(.maxdisk)\n  maxmem: \(.maxmem)\n  cpus: \(.cpus)"' "$tmpresp"
fi
