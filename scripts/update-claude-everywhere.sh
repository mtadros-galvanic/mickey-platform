#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TFVARS_FILE="${TFVARS_FILE:-$ROOT/envs/prod/terraform.tfvars}"
PVE_HOST="${PVE_HOST:-root@10.25.1.207}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/mickey}"
GUEST_USER="${GUEST_USER:-galvanic}"
WAIT_FOR_SSH_SECONDS="${WAIT_FOR_SSH_SECONDS:-360}"
UPDATE_STOPPED_VMS="${UPDATE_STOPPED_VMS:-1}"
DRY_RUN="${DRY_RUN:-0}"
CLAUDE_RELEASE="${CLAUDE_RELEASE:-}"
CLAUDE_INSTALL_SCRIPT_URL="${CLAUDE_INSTALL_SCRIPT_URL:-https://claude.ai/install.sh}"
UPDATE_ATTEMPTS="${UPDATE_ATTEMPTS:-3}"
RETRY_DELAY_SECONDS="${RETRY_DELAY_SECONDS:-5}"
LOCK_FILE="${LOCK_FILE:-/tmp/mickey-claude-update-everywhere.lock}"
ONLY_HOSTS="${ONLY_HOSTS:-}"
SKIP_HOSTS="${SKIP_HOSTS:-mickey-thud}"

SELECTED_RELEASE=""
INSTALLER_PAYLOAD=""
CURRENT_HOST=""
LOCK_FD=""
LAST_BEFORE="unknown"
LAST_AFTER="unknown"
LAST_STATUS="failed"
LAST_DETAIL=""

declare -a RESULT_HOSTS=()
declare -a RESULT_STATES=()
declare -a RESULT_BEFORE=()
declare -a RESULT_AFTER=()
declare -a RESULT_STATUS=()
declare -a RESULT_DETAILS=()
declare -A STARTED_VMS=()

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

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "required file not found: $path" >&2
    return 1
  fi
}

require_positive_integer() {
  local name="$1"
  local value="$2"
  if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "$name must be a positive integer, got: $value" >&2
    return 1
  fi
}

host_is_selected() {
  local name="$1"
  if [[ ",$SKIP_HOSTS," == *",$name,"* ]]; then
    return 1
  fi
  if [[ -z "$ONLY_HOSTS" ]]; then
    return 0
  fi
  [[ ",$ONLY_HOSTS," == *",$name,"* ]]
}

normalize_release() {
  local release="$1"
  case "$release" in
    ""|latest|stable)
      printf '\n'
      ;;
    v*)
      printf '%s\n' "${release#v}"
      ;;
    *)
      printf '%s\n' "$release"
      ;;
  esac
}

validate_release() {
  local release="$1"
  if [[ -n "$release" && ! "$release" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "invalid Claude Code release: $release" >&2
    return 1
  fi
}

retry_delay() {
  local attempt="$1"
  sleep "$((RETRY_DELAY_SECONDS * attempt))"
}

fetch_installer() {
  local installer
  local attempt
  local error=""

  if [[ "$DRY_RUN" == "1" ]]; then
    INSTALLER_PAYLOAD="dry-run"
    return 0
  fi

  installer="$(mktemp)" || return 1
  for ((attempt = 1; attempt <= UPDATE_ATTEMPTS; attempt++)); do
    log "fetching the Claude Code installer (attempt $attempt/$UPDATE_ATTEMPTS)"
    if error="$(curl -fsSL "$CLAUDE_INSTALL_SCRIPT_URL" -o "$installer" 2>&1)"; then
      if grep -qi claude "$installer"; then
        INSTALLER_PAYLOAD="$(base64 -w 0 "$installer")"
        rm -f "$installer"
        return 0
      fi
      error="downloaded installer does not mention Claude"
    fi
    if (( attempt < UPDATE_ATTEMPTS )); then
      retry_delay "$attempt"
    fi
  done

  rm -f "$installer"
  echo "failed to fetch a usable Claude Code installer after $UPDATE_ATTEMPTS attempts: $error" >&2
  return 1
}

acquire_lock() {
  exec {LOCK_FD}>"$LOCK_FILE" || return 1
  if ! flock -n "$LOCK_FD"; then
    echo "another Claude fleet update holds $LOCK_FILE" >&2
    return 1
  fi
}

record_result() {
  RESULT_HOSTS+=("$1")
  RESULT_STATES+=("$2")
  RESULT_BEFORE+=("$3")
  RESULT_AFTER+=("$4")
  RESULT_STATUS+=("$5")
  RESULT_DETAILS+=("$6")
}

print_summary() {
  local i

  printf '\n%-27s %-9s %-12s %-12s %-9s %s\n' \
    "HOST" "STATE" "BEFORE" "AFTER" "RESULT" "DETAIL"
  printf '%-27s %-9s %-12s %-12s %-9s %s\n' \
    "---------------------------" "---------" "------------" "------------" "---------" "------"
  for ((i = 0; i < ${#RESULT_HOSTS[@]}; i++)); do
    printf '%-27s %-9s %-12s %-12s %-9s %s\n' \
      "${RESULT_HOSTS[$i]}" \
      "${RESULT_STATES[$i]}" \
      "${RESULT_BEFORE[$i]}" \
      "${RESULT_AFTER[$i]}" \
      "${RESULT_STATUS[$i]}" \
      "${RESULT_DETAILS[$i]}"
  done
}

result_has_failures() {
  local status
  for status in "${RESULT_STATUS[@]}"; do
    if [[ "$status" == "failed" ]]; then
      return 0
    fi
  done
  return 1
}

claude_install_command() {
  local release="$1"
  printf "requested_release='%s'\n" "$release"
  printf "installer_payload='%s'\n" "$INSTALLER_PAYLOAD"
  cat <<'EOF'
set -u
export DISABLE_AUTOUPDATER=1
launcher="$HOME/.local/bin/claude-launcher"
wrapper_target="$HOME/.local/bin/claude"
wrapper_source="$HOME/.local/lib/mickey/claude-wrapper"
before="unknown"
after="unknown"
installer="$(mktemp)" || exit 1
trap 'rm -f "$installer"' EXIT

if [ -x "$launcher" ]; then
  before="$("$launcher" --version 2>/dev/null | awk '{print $1}' || true)"
  [ -n "$before" ] || before="unknown"
fi
printf 'MICKEY_CLAUDE_BEFORE\t%s\n' "$before"

if ! printf '%s' "$installer_payload" | base64 -d >"$installer"; then
  echo "failed to decode the centrally fetched Claude Code installer" >&2
  exit 1
fi

if [ -n "$requested_release" ]; then
  bash "$installer" "$requested_release" </dev/null || exit 1
else
  bash "$installer" </dev/null || exit 1
fi

if [ -e "$wrapper_target" ] && ! head -n 2 "$wrapper_target" 2>/dev/null | grep -q mickey-managed; then
  if [ -L "$wrapper_target" ]; then
    ln -sfn "$(readlink -f "$wrapper_target")" "$launcher"
    rm -f "$wrapper_target"
  else
    mv -f "$wrapper_target" "$launcher"
  fi
fi
if [ -f "$wrapper_source" ]; then
  cp -f "$wrapper_source" "$wrapper_target"
  chmod 0755 "$wrapper_target"
fi

if [ -x "$launcher" ]; then
  after="$("$launcher" --version 2>/dev/null | awk '{print $1}' || true)"
  [ -n "$after" ] || after="unknown"
fi
printf 'MICKEY_CLAUDE_AFTER\t%s\n' "$after"

versions_dir="$HOME/.local/share/claude/versions"
if [ -d "$versions_dir" ]; then
  keep_target="$(readlink -f "$launcher" 2>/dev/null || true)"
  ls -1 "$versions_dir" 2>/dev/null | sort -V | head -n -3 | while IFS= read -r old_version; do
    [ -n "$old_version" ] || continue
    case "$keep_target" in
      "$versions_dir/$old_version"*) continue ;;
    esac
    rm -rf "$versions_dir/${old_version:?}"
  done
fi

if [ -n "$requested_release" ]; then
  [ "$after" = "$requested_release" ]
else
  [ "$after" != "unknown" ]
fi
EOF
}

run_target_once() {
  local mode="$1"
  local target="$2"
  local command="$3"

  case "$mode" in
    local)
      sh -c "$command"
      ;;
    guest)
      "${ssh_guest_common[@]}" "$target" "$command"
      ;;
    *)
      echo "unsupported update mode: $mode" >&2
      return 2
      ;;
  esac
}

marker_value() {
  local marker="$1"
  awk -F '\t' -v marker="$marker" '$1 == marker { value=$2 } END { print value }'
}

perform_claude_update() {
  local label="$1"
  local mode="$2"
  local target="$3"
  local release="$4"
  local command
  local output
  local visible_output
  local attempt
  local rc=1

  LAST_BEFORE="unknown"
  LAST_AFTER="unknown"
  LAST_STATUS="failed"
  LAST_DETAIL="not attempted"

  if [[ "$DRY_RUN" == "1" ]]; then
    log "would update $label to Claude Code ${release:-latest}"
    LAST_STATUS="planned"
    LAST_DETAIL="dry run"
    return 0
  fi

  command="$(claude_install_command "$release")" || return 1
  for ((attempt = 1; attempt <= UPDATE_ATTEMPTS; attempt++)); do
    log "updating $label to Claude Code ${release:-latest} (attempt $attempt/$UPDATE_ATTEMPTS)"
    if output="$(run_target_once "$mode" "$target" "$command" 2>&1)"; then
      rc=0
    else
      rc=$?
    fi

    LAST_BEFORE="$(marker_value MICKEY_CLAUDE_BEFORE <<<"$output")"
    LAST_AFTER="$(marker_value MICKEY_CLAUDE_AFTER <<<"$output")"
    [[ -n "$LAST_BEFORE" ]] || LAST_BEFORE="unknown"
    [[ -n "$LAST_AFTER" ]] || LAST_AFTER="unknown"
    visible_output="$(sed '/^MICKEY_CLAUDE_\(BEFORE\|AFTER\)[[:space:]]/d' <<<"$output")"
    if [[ -n "$visible_output" ]]; then
      printf '%s\n' "$visible_output"
    fi

    if (( rc == 0 )) && [[ "$LAST_AFTER" != "unknown" ]] \
      && { [[ -z "$release" ]] || [[ "$LAST_AFTER" == "$release" ]]; }; then
      if [[ "$LAST_BEFORE" == "$LAST_AFTER" ]]; then
        LAST_STATUS="current"
        LAST_DETAIL="verified"
      else
        LAST_STATUS="updated"
        LAST_DETAIL="verified"
      fi
      return 0
    fi

    if (( attempt < UPDATE_ATTEMPTS )); then
      log "$label update failed with exit $rc; retrying"
      retry_delay "$attempt"
    fi
  done

  LAST_STATUS="failed"
  LAST_DETAIL="attempts=$UPDATE_ATTEMPTS exit=$rc"
  return 1
}

pve_qm_status() {
  local vmid="$1"
  "${ssh_common[@]}" "$PVE_HOST" "qm status $vmid" | awk '{print $2}'
}

pve_qm_start() {
  local vmid="$1"
  log "starting VM $vmid"
  "${ssh_common[@]}" "$PVE_HOST" "qm start $vmid"
}

pve_qm_shutdown_or_stop() {
  local vmid="$1"
  log "stopping VM $vmid"
  "${ssh_common[@]}" "$PVE_HOST" "qm shutdown $vmid --timeout 120 || qm stop $vmid"
}

cleanup_started_vms() {
  local rc=$?
  local vmid
  trap - EXIT
  for vmid in "${!STARTED_VMS[@]}"; do
    log "cleanup: restoring ${STARTED_VMS[$vmid]} ($vmid) to stopped state"
    pve_qm_shutdown_or_stop "$vmid" || true
  done
  exit "$rc"
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

pve_guest_ipv4() {
  local vmid="$1"
  local interface_name="$2"

  "${ssh_common[@]}" "$PVE_HOST" "qm guest cmd $vmid network-get-interfaces" \
    | python3 -c '
import json
import sys

interface_name = sys.argv[1]
interfaces = json.load(sys.stdin)
addresses = [
    address["ip-address"]
    for interface in interfaces
    if interface.get("name") == interface_name
    for address in interface.get("ip-addresses", [])
    if address.get("ip-address-type") == "ipv4"
    and address.get("ip-address") != "127.0.0.1"
    and not address.get("ip-address", "").startswith("169.254.")
]
if len(addresses) != 1:
    raise SystemExit(
        f"expected one IPv4 address on {interface_name}, found {addresses}"
    )
print(addresses[0])
' "$interface_name"
}

wait_for_guest_ipv4() {
  local name="$1"
  local vmid="$2"
  local interface_name="$3"
  local deadline
  local discovered_ip
  deadline=$((SECONDS + WAIT_FOR_SSH_SECONDS))

  log "waiting for the QEMU guest agent address on $name ($interface_name)" >&2
  while (( SECONDS < deadline )); do
    discovered_ip="$(pve_guest_ipv4 "$vmid" "$interface_name" 2>/dev/null || true)"
    if [[ -n "$discovered_ip" ]]; then
      printf '%s\n' "$discovered_ip"
      return 0
    fi
    sleep 5
  done

  echo "timed out waiting for the QEMU guest agent address on $name" >&2
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
    network_mode = re.search(r'(?m)^\s*network_mode\s*=\s*"([^"]+)"', body)
    guest_agent_interface = re.search(
        r'(?m)^\s*guest_agent_interface\s*=\s*"([^"]+)"', body
    )

    if not (template and vmid):
        continue
    if not template.group(1).startswith("ubuntu-"):
        continue

    mode = network_mode.group(1) if network_mode else "static"
    interface_name = guest_agent_interface.group(1) if guest_agent_interface else "eth0"
    if mode == "static":
        if not ip:
            raise SystemExit(f"static VM {name} is missing lan_ipv4_cidr")
        address = ip.group(1)
    elif mode == "dhcp":
        address = "dhcp"
    else:
        raise SystemExit(f"unsupported network_mode for {name}: {mode}")

    print(f"{name}\t{vmid.group(1)}\t{address}\t{interface_name}")
PY
}

update_guest_vm() {
  local name="$1"
  local vmid="$2"
  local ip="$3"
  local guest_agent_interface="$4"
  local current_status
  local started_here=0
  local update_rc=0
  local cleanup_rc=0

  if [[ "$name" == "$CURRENT_HOST" ]] || ! host_is_selected "$name"; then
    return 0
  fi

  if ! current_status="$(pve_qm_status "$vmid" 2>/dev/null)"; then
    record_result "$name" "unknown" "unknown" "unknown" "failed" "could not read VM state"
    return 0
  fi
  log "$name ($vmid, $ip) is $current_status"

  case "$current_status" in
    running)
      ;;
    stopped)
      if [[ "$UPDATE_STOPPED_VMS" != "1" ]]; then
        record_result "$name" "$current_status" "unknown" "unknown" "skipped" "UPDATE_STOPPED_VMS=$UPDATE_STOPPED_VMS"
        return 0
      fi
      if [[ "$DRY_RUN" != "1" ]]; then
        if ! pve_qm_start "$vmid"; then
          record_result "$name" "$current_status" "unknown" "unknown" "failed" "could not start VM"
          return 0
        fi
        started_here=1
        STARTED_VMS[$vmid]="$name"
      fi
      ;;
    *)
      record_result "$name" "$current_status" "unknown" "unknown" "skipped" "unsupported VM state"
      return 0
      ;;
  esac

  if [[ "$DRY_RUN" != "1" ]]; then
    if [[ "$ip" == "dhcp" ]]; then
      if ! ip="$(wait_for_guest_ipv4 "$name" "$vmid" "$guest_agent_interface")"; then
        LAST_BEFORE="unknown"
        LAST_AFTER="unknown"
        LAST_STATUS="failed"
        LAST_DETAIL="guest address unavailable"
        update_rc=1
      else
        log "discovered $name at $ip through the QEMU guest agent"
      fi
    fi

    if (( update_rc == 0 )) && ! wait_for_guest_ssh "$name" "$ip"; then
      LAST_BEFORE="unknown"
      LAST_AFTER="unknown"
      LAST_STATUS="failed"
      LAST_DETAIL="SSH unavailable"
      update_rc=1
    fi
  fi

  if (( update_rc == 0 )); then
    perform_claude_update "$name" guest "$GUEST_USER@$ip" "$SELECTED_RELEASE" || update_rc=$?
  fi

  if (( started_here == 1 )); then
    if pve_qm_shutdown_or_stop "$vmid"; then
      unset 'STARTED_VMS[$vmid]'
    else
      cleanup_rc=$?
      LAST_STATUS="failed"
      LAST_DETAIL="${LAST_DETAIL:+$LAST_DETAIL; }failed to restore stopped state"
    fi
  fi

  record_result "$name" "$current_status" "$LAST_BEFORE" "$LAST_AFTER" "$LAST_STATUS" "$LAST_DETAIL"
  (( update_rc == 0 && cleanup_rc == 0 ))
}

show_help() {
  cat <<EOF
usage: $(basename "$0") [--list]

Updates Claude Code on the controller and the Terraform-managed Ubuntu VMs.
The controller updates first (to the requested or newest release); the version
it ends up on is then installed verbatim on every other host.

Environment:
  CLAUDE_RELEASE=            Explicit release (empty resolves to the newest).
  ONLY_HOSTS=a,b             Update only the named hosts (useful for canaries).
  SKIP_HOSTS=mickey-thud     Hosts never updated (default: mickey-thud, glibc too old).
  UPDATE_ATTEMPTS=3          Retry each installer fetch and host update.
  RETRY_DELAY_SECONDS=5      Base delay for linear retry backoff.
  UPDATE_STOPPED_VMS=1       Start stopped VMs temporarily and restore their state.
  DRY_RUN=1                  List actions without changing hosts.
EOF
}

main() {
  local name
  local vmid
  local ip
  local guest_agent_interface
  local requested
  case "${1:-}" in
    --list)
      require_file "$TFVARS_FILE" || return 1
      load_linux_vms
      return 0
      ;;
    -h|--help)
      show_help
      return 0
      ;;
    "")
      ;;
    *)
      show_help >&2
      return 2
      ;;
  esac

  require_file "$TFVARS_FILE" || return 1
  require_positive_integer UPDATE_ATTEMPTS "$UPDATE_ATTEMPTS" || return 1
  require_positive_integer RETRY_DELAY_SECONDS "$RETRY_DELAY_SECONDS" || return 1
  if [[ ! -r "$SSH_KEY" ]]; then
    echo "SSH key is not readable: $SSH_KEY" >&2
    return 1
  fi
  requested="$(normalize_release "$CLAUDE_RELEASE")" || return 1
  validate_release "$requested" || return 1
  acquire_lock || return 1
  trap cleanup_started_vms EXIT

  CURRENT_HOST="$(hostname -s)"
  log "starting Mickey Claude Code update"
  fetch_installer || return 1

  if ! host_is_selected "$CURRENT_HOST"; then
    echo "the controller ($CURRENT_HOST) must be selected: it pins the fleet release" >&2
    return 1
  fi

  if ! perform_claude_update "$CURRENT_HOST" local "" "$requested"; then
    record_result "$CURRENT_HOST" "local" "$LAST_BEFORE" "$LAST_AFTER" "$LAST_STATUS" "$LAST_DETAIL"
    print_summary
    log "controller update failed; aborting before touching the fleet"
    return 1
  fi
  record_result "$CURRENT_HOST" "local" "$LAST_BEFORE" "$LAST_AFTER" "$LAST_STATUS" "$LAST_DETAIL"

  if [[ "$DRY_RUN" == "1" ]]; then
    SELECTED_RELEASE="$requested"
  else
    SELECTED_RELEASE="$LAST_AFTER"
    validate_release "$SELECTED_RELEASE" || return 1
  fi
  log "selected Claude Code release ${SELECTED_RELEASE:-latest}"

  while IFS=$'\t' read -r name vmid ip guest_agent_interface; do
    update_guest_vm "$name" "$vmid" "$ip" "$guest_agent_interface" || true
  done < <(load_linux_vms)

  print_summary
  if result_has_failures; then
    log "finished Mickey Claude Code update with failures"
    return 1
  fi

  log "finished Mickey Claude Code update successfully"
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
