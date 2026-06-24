#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TFVARS_FILE="${TFVARS_FILE:-$ROOT/envs/prod/terraform.tfvars}"
PVE_HOST="${PVE_HOST:-root@10.25.1.207}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/mickey}"
GUEST_USER="${GUEST_USER:-galvanic}"
WAIT_FOR_SSH_SECONDS="${WAIT_FOR_SSH_SECONDS:-360}"
UPDATE_STOPPED_VMS="${UPDATE_STOPPED_VMS:-1}"
DRY_RUN="${DRY_RUN:-0}"
LOCAL_CODEX_UPDATED=0

ssh_common=(
  ssh
  -n
  -i "$SSH_KEY"
  -o BatchMode=yes
  -o ConnectTimeout=8
  -o IdentitiesOnly=yes
  -o LogLevel=ERROR
)

ssh_guest_common=(
  "${ssh_common[@]}"
  -o UserKnownHostsFile=/dev/null
  -o StrictHostKeyChecking=no
)

log() {
  printf '[%(%Y-%m-%dT%H:%M:%SZ)T] %s\n' -1 "$*"
}

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'DRY_RUN:'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "required file not found: $path" >&2
    exit 1
  fi
}

update_local_codex() {
  log "updating local host: $(hostname)"
  if command -v codex-update >/dev/null 2>&1; then
    run codex-update
  else
    (
      installer="$(mktemp)"
      trap 'rm -f "$installer"' EXIT
      run curl -fsSL https://chatgpt.com/codex/install.sh -o "$installer"
      run chmod 0755 "$installer"
      if [[ "$DRY_RUN" != "1" ]]; then
        CODEX_HOME="$HOME/.local/state/codex/home" \
          CODEX_INSTALL_DIR="$HOME/.local/lib/codex/bin" \
          CODEX_NON_INTERACTIVE=true \
          PATH="$HOME/.local/lib/codex/bin:/usr/local/bin:/usr/bin:/bin" \
          setsid sh "$installer" </dev/null
      fi
    )
  fi
  if [[ "$DRY_RUN" != "1" ]]; then
    codex --version
  fi
  LOCAL_CODEX_UPDATED=1
}

remote_codex_update_command() {
  cat <<'EOF'
set -eu
if command -v codex-update >/dev/null 2>&1; then
  codex-update
else
  installer="$(mktemp)"
  trap 'rm -f "$installer"' EXIT
  curl -fsSL https://chatgpt.com/codex/install.sh -o "$installer"
  chmod 0755 "$installer"
  CODEX_HOME="$HOME/.local/state/codex/home" \
    CODEX_INSTALL_DIR="$HOME/.local/lib/codex/bin" \
    CODEX_NON_INTERACTIVE=true \
    PATH="$HOME/.local/lib/codex/bin:/usr/local/bin:/usr/bin:/bin" \
    setsid sh "$installer" </dev/null
fi
codex --version
EOF
}

update_remote_codex() {
  local label="$1"
  local target="$2"
  log "updating $label"
  run "${ssh_guest_common[@]}" "$target" "$(remote_codex_update_command)"
}

update_pve_codex() {
  log "updating mickey-pve"
  run "${ssh_common[@]}" "$PVE_HOST" "$(remote_codex_update_command)"
}

pve_qm_status() {
  local vmid="$1"
  "${ssh_common[@]}" "$PVE_HOST" "qm status $vmid" | awk '{print $2}'
}

pve_qm_start() {
  local vmid="$1"
  log "starting VM $vmid"
  run "${ssh_common[@]}" "$PVE_HOST" "qm start $vmid || true"
}

pve_qm_shutdown_or_stop() {
  local vmid="$1"
  log "stopping VM $vmid"
  if [[ "$DRY_RUN" == "1" ]]; then
    run "${ssh_common[@]}" "$PVE_HOST" "qm shutdown $vmid --timeout 120 || qm stop $vmid"
  else
    "${ssh_common[@]}" "$PVE_HOST" "qm shutdown $vmid --timeout 120 || qm stop $vmid"
  fi
}

wait_for_guest_ssh() {
  local name="$1"
  local ip="$2"
  local deadline
  deadline=$((SECONDS + WAIT_FOR_SSH_SECONDS))

  log "waiting for SSH on $name ($ip)"
  while (( SECONDS < deadline )); do
    if "${ssh_guest_common[@]}" "$GUEST_USER@$ip" "true" >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
  done

  echo "timed out waiting for SSH on $name ($ip)" >&2
  return 1
}

load_linux_vms() {
  python3 - "$TFVARS_FILE" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
match = re.search(r'(?m)^\s*vms\s*=\s*\{', text)
if not match:
    sys.exit("could not find vms block in tfvars")

start = match.end()
depth = 1
pos = start
while pos < len(text) and depth:
    if text[pos] == "{":
        depth += 1
    elif text[pos] == "}":
        depth -= 1
    pos += 1

vms_body = text[start : pos - 1]
entry_re = re.compile(r'"([^"]+)"\s*=\s*\{')
cursor = 0
while True:
    entry = entry_re.search(vms_body, cursor)
    if not entry:
        break

    name = entry.group(1)
    body_start = entry.end()
    depth = 1
    i = body_start
    while i < len(vms_body) and depth:
        if vms_body[i] == "{":
            depth += 1
        elif vms_body[i] == "}":
            depth -= 1
        i += 1

    body = vms_body[body_start : i - 1]
    cursor = i

    template = re.search(r'(?m)^\s*clone_template_name\s*=\s*"([^"]+)"', body)
    vmid = re.search(r'(?m)^\s*vm_id\s*=\s*([0-9]+)', body)
    ip = re.search(r'(?m)^\s*lan_ipv4_cidr\s*=\s*"([^"/]+)(?:/[0-9]+)?"', body)

    if not (template and vmid and ip):
        continue
    if not template.group(1).startswith("ubuntu-"):
        continue

    print(f"{name}\t{vmid.group(1)}\t{ip.group(1)}")
PY
}

update_guest_vm() {
  local name="$1"
  local vmid="$2"
  local ip="$3"
  local current_status
  local started_here=0
  local current_host

  current_host="$(hostname -s)"
  if [[ "$name" == "$current_host" ]]; then
    if [[ "$LOCAL_CODEX_UPDATED" == "1" ]]; then
      log "local host already updated as $name"
      return 0
    fi
    update_local_codex
    return 0
  fi

  current_status="$(pve_qm_status "$vmid")"
  log "$name ($vmid, $ip) is $current_status"

  case "$current_status" in
    running)
      ;;
    stopped)
      if [[ "$UPDATE_STOPPED_VMS" != "1" ]]; then
        log "skipping stopped VM $name because UPDATE_STOPPED_VMS=$UPDATE_STOPPED_VMS"
        return 0
      fi
      pve_qm_start "$vmid"
      started_here=1
      ;;
    *)
      log "skipping $name because VM status is $current_status"
      return 0
      ;;
  esac

  if [[ "$DRY_RUN" == "1" ]]; then
    log "would update $name at $ip"
    if [[ "$started_here" == "1" ]]; then
      log "would stop $name after update"
    fi
    return 0
  fi

  if ! wait_for_guest_ssh "$name" "$ip"; then
    if [[ "$started_here" == "1" ]]; then
      pve_qm_shutdown_or_stop "$vmid" || true
    fi
    return 1
  fi

  update_remote_codex "$name" "$GUEST_USER@$ip"

  if [[ "$started_here" == "1" ]]; then
    pve_qm_shutdown_or_stop "$vmid"
  fi
}

main() {
  case "${1:-}" in
    --list)
      require_file "$TFVARS_FILE"
      load_linux_vms
      return 0
      ;;
    -h|--help)
      cat <<EOF
usage: $(basename "$0") [--list]

Updates Codex on the controller, mickey-pve, and all Terraform-managed Ubuntu VMs.
Set DRY_RUN=1 to print actions without running updates.
Set UPDATE_STOPPED_VMS=0 to skip VMs that are currently powered off.
EOF
      return 0
      ;;
  esac

  require_file "$TFVARS_FILE"
  if [[ ! -r "$SSH_KEY" ]]; then
    echo "SSH key is not readable: $SSH_KEY" >&2
    exit 1
  fi

  log "starting Mickey Codex update"
  update_local_codex
  update_pve_codex

  while IFS=$'\t' read -r name vmid ip; do
    update_guest_vm "$name" "$vmid" "$ip"
  done < <(load_linux_vms)

  log "finished Mickey Codex update"
}

main "$@"
