#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PROXMOX_SSH_TARGET="${PROXMOX_SSH_TARGET:-root@10.25.1.207}"
PROXMOX_SSH_KEY="${PROXMOX_SSH_KEY:-$HOME/.ssh/mickey}"
PROXMOX_BRIDGE="${PROXMOX_BRIDGE:-vmbr0}"
PROXMOX_STORAGE="${PROXMOX_STORAGE:-local-lvm}"
SERVER_TEMPLATE_ID="${SERVER_TEMPLATE_ID:-9000}"
DESKTOP_TEMPLATE_ID="${DESKTOP_TEMPLATE_ID:-9001}"
SERVER_TEMPLATE_NAME="${SERVER_TEMPLATE_NAME:-ubuntu-24-04-server-cloudinit}"
DESKTOP_TEMPLATE_NAME="${DESKTOP_TEMPLATE_NAME:-ubuntu-24-04-desktop-cloudinit}"
UBUNTU_CLOUD_IMAGE_URL="${UBUNTU_CLOUD_IMAGE_URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}"
PROXMOX_IMAGE_CACHE_DIR="${PROXMOX_IMAGE_CACHE_DIR:-/var/lib/vz/template/cache}"
BUILD_DESKTOP_TEMPLATE="${BUILD_DESKTOP_TEMPLATE:-1}"
FORCE_REBUILD=0

usage() {
  cat <<'EOF'
usage: build-proxmox-templates.sh [--force]

Builds the default Ubuntu 24.04 server template expected by envs/prod/terraform.tfvars.
It can also clone an optional desktop-flavored template when BUILD_DESKTOP_TEMPLATE=1.

Environment overrides:
  PROXMOX_SSH_TARGET      SSH target for the Proxmox host
  PROXMOX_SSH_KEY         SSH private key used to reach the Proxmox host
  PROXMOX_BRIDGE          Proxmox bridge for the imported template NIC
  PROXMOX_STORAGE         Proxmox storage for the imported disks and cloud-init drive
  SERVER_TEMPLATE_ID      VMID for the server template
  DESKTOP_TEMPLATE_ID     VMID for the desktop template clone
  SERVER_TEMPLATE_NAME    Name for the server template
  DESKTOP_TEMPLATE_NAME   Name for the desktop template clone
  UBUNTU_CLOUD_IMAGE_URL  Source image URL
  PROXMOX_IMAGE_CACHE_DIR Download location on the Proxmox host
  BUILD_DESKTOP_TEMPLATE  1 to clone a desktop template, 0 to build the server template only
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE_REBUILD=1
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

for tool in ssh; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "missing required tool: $tool" >&2
    exit 1
  fi
done

if [[ ! -f "$PROXMOX_SSH_KEY" ]]; then
  echo "ssh key not found: $PROXMOX_SSH_KEY" >&2
  exit 1
fi

ssh_args=(
  -i "$PROXMOX_SSH_KEY"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
)

read -r -d '' remote_script <<'EOF' || true
set -euo pipefail

SERVER_TEMPLATE_ID="$1"
DESKTOP_TEMPLATE_ID="$2"
SERVER_TEMPLATE_NAME="$3"
DESKTOP_TEMPLATE_NAME="$4"
PROXMOX_BRIDGE="$5"
PROXMOX_STORAGE="$6"
UBUNTU_CLOUD_IMAGE_URL="$7"
PROXMOX_IMAGE_CACHE_DIR="$8"
FORCE_REBUILD="$9"
BUILD_DESKTOP_TEMPLATE="${10}"

for tool in qm wget; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "missing required tool on Proxmox host: $tool" >&2
    exit 1
  fi
done

image_filename="$(basename "$UBUNTU_CLOUD_IMAGE_URL")"
image_path="$PROXMOX_IMAGE_CACHE_DIR/$image_filename"

ensure_cloud_image() {
  mkdir -p "$PROXMOX_IMAGE_CACHE_DIR"
  if [[ -f "$image_path" ]]; then
    echo "using cached cloud image: $image_path"
    return
  fi

  echo "downloading cloud image: $UBUNTU_CLOUD_IMAGE_URL"
  wget -O "${image_path}.partial" "$UBUNTU_CLOUD_IMAGE_URL"
  mv "${image_path}.partial" "$image_path"
}

vm_exists() {
  qm config "$1" >/dev/null 2>&1
}

assert_missing_or_destroy() {
  local vmid="$1"
  local label="$2"

  if ! vm_exists "$vmid"; then
    return
  fi

  if [[ "$FORCE_REBUILD" != "1" ]]; then
    echo "$label already exists as VMID $vmid. Re-run with --force to rebuild it." >&2
    exit 1
  fi

  echo "destroying existing $label VMID $vmid"
  qm stop "$vmid" >/dev/null 2>&1 || true
  qm destroy "$vmid" --destroy-unreferenced-disks 1 >/dev/null 2>&1 || qm destroy "$vmid"
}

create_server_template() {
  echo "creating server template $SERVER_TEMPLATE_NAME ($SERVER_TEMPLATE_ID)"

  qm create "$SERVER_TEMPLATE_ID" \
    --name "$SERVER_TEMPLATE_NAME" \
    --memory 4096 \
    --cores 2 \
    --cpu host \
    --ostype l26 \
    --machine q35 \
    --bios ovmf \
    --scsihw virtio-scsi-single \
    --net0 "virtio,bridge=$PROXMOX_BRIDGE"

  qm set "$SERVER_TEMPLATE_ID" --efidisk0 "$PROXMOX_STORAGE":0,efitype=4m,pre-enrolled-keys=1
  qm set "$SERVER_TEMPLATE_ID" --scsi0 "$PROXMOX_STORAGE":0,import-from="$image_path",discard=on,ssd=1
  qm set "$SERVER_TEMPLATE_ID" --ide2 "$PROXMOX_STORAGE":cloudinit
  qm set "$SERVER_TEMPLATE_ID" --boot order=scsi0
  qm set "$SERVER_TEMPLATE_ID" --serial0 socket --vga serial0
  qm set "$SERVER_TEMPLATE_ID" --agent enabled=1,fstrim_cloned_disks=1
  qm template "$SERVER_TEMPLATE_ID"
}

create_desktop_template() {
  echo "creating desktop template $DESKTOP_TEMPLATE_NAME ($DESKTOP_TEMPLATE_ID) from the same base image"
  qm clone "$SERVER_TEMPLATE_ID" "$DESKTOP_TEMPLATE_ID" --name "$DESKTOP_TEMPLATE_NAME" --full 1
  qm template "$DESKTOP_TEMPLATE_ID"
}

ensure_cloud_image

if [[ "$BUILD_DESKTOP_TEMPLATE" == "1" ]]; then
  assert_missing_or_destroy "$DESKTOP_TEMPLATE_ID" "desktop template"
fi

assert_missing_or_destroy "$SERVER_TEMPLATE_ID" "server template"
create_server_template

if [[ "$BUILD_DESKTOP_TEMPLATE" == "1" ]]; then
  create_desktop_template
fi

echo
echo "templates ready:"
if [[ "$BUILD_DESKTOP_TEMPLATE" == "1" ]]; then
  qm list | awk -v a="$SERVER_TEMPLATE_ID" -v b="$DESKTOP_TEMPLATE_ID" '$1 == a || $1 == b { print }'
else
  qm list | awk -v a="$SERVER_TEMPLATE_ID" '$1 == a { print }'
fi
EOF

ssh "${ssh_args[@]}" "$PROXMOX_SSH_TARGET" bash -s -- \
  "$SERVER_TEMPLATE_ID" \
  "$DESKTOP_TEMPLATE_ID" \
  "$SERVER_TEMPLATE_NAME" \
  "$DESKTOP_TEMPLATE_NAME" \
  "$PROXMOX_BRIDGE" \
  "$PROXMOX_STORAGE" \
  "$UBUNTU_CLOUD_IMAGE_URL" \
  "$PROXMOX_IMAGE_CACHE_DIR" \
  "$FORCE_REBUILD" \
  "$BUILD_DESKTOP_TEMPLATE" <<<"$remote_script"
