#!/usr/bin/env bash
set -euo pipefail

CURRENT_IP="${CURRENT_IP:-10.25.1.101}"
NEW_IP="${NEW_IP:-10.25.1.207}"
PROXMOX_SSH_USER="${PROXMOX_SSH_USER:-root}"
PROXMOX_SSH_KEY="${PROXMOX_SSH_KEY:-$HOME/.ssh/mickey}"
ROLLBACK_SECONDS="${ROLLBACK_SECONDS:-300}"
APPLY="${APPLY:-0}"
ALLOW_PING_RESPONSE="${ALLOW_PING_RESPONSE:-0}"

usage() {
  cat <<'EOF'
usage: reip-proxmox-host.sh [--apply] [--current-ip IP] [--new-ip IP]

Safely moves the standalone Proxmox management address by:
  1. Backing up /etc/network/interfaces and /etc/hosts on the host
  2. Arming an automatic rollback timer
  3. Updating the host from CURRENT_IP to NEW_IP
  4. Reconnecting on NEW_IP and cancelling the rollback if verification succeeds

Environment overrides:
  CURRENT_IP           Current Proxmox management IP
  NEW_IP               New Proxmox management IP
  PROXMOX_SSH_USER     SSH user for the Proxmox host
  PROXMOX_SSH_KEY      SSH key for the Proxmox host
  ROLLBACK_SECONDS     Seconds before the rollback fires if verification fails
  APPLY                1 to make the change, 0 for a dry run
  ALLOW_PING_RESPONSE  1 to proceed even if NEW_IP answers ping before the cutover
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --current-ip)
      CURRENT_IP="$2"
      shift 2
      ;;
    --new-ip)
      NEW_IP="$2"
      shift 2
      ;;
    --ssh-user)
      PROXMOX_SSH_USER="$2"
      shift 2
      ;;
    --ssh-key)
      PROXMOX_SSH_KEY="$2"
      shift 2
      ;;
    --rollback-seconds)
      ROLLBACK_SECONDS="$2"
      shift 2
      ;;
    --allow-ping-response)
      ALLOW_PING_RESPONSE=1
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

for tool in ping ssh; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "missing required tool: $tool" >&2
    exit 1
  fi
done

if [[ ! -f "$PROXMOX_SSH_KEY" ]]; then
  echo "ssh key not found: $PROXMOX_SSH_KEY" >&2
  exit 1
fi

current_target="${PROXMOX_SSH_USER}@${CURRENT_IP}"
new_target="${PROXMOX_SSH_USER}@${NEW_IP}"
ssh_args=(
  -i "$PROXMOX_SSH_KEY"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=5
)

ssh_current() {
  ssh "${ssh_args[@]}" "$current_target" "$@"
}

ssh_new() {
  ssh "${ssh_args[@]}" "$new_target" "$@"
}

echo "Current target: $current_target"
echo "New target:     $new_target"
echo "Rollback:       ${ROLLBACK_SECONDS}s"
echo
echo "Current Proxmox network state:"
ssh_current '
  hostname -f
  ip -4 addr show vmbr0
  ip route
  printf "\n--- /etc/network/interfaces ---\n"
  sed -n "1,160p" /etc/network/interfaces
  printf "\n--- /etc/hosts ---\n"
  sed -n "1,120p" /etc/hosts
'

if ping -c 1 -W 1 "$NEW_IP" >/dev/null 2>&1; then
  if [[ "$ALLOW_PING_RESPONSE" != "1" ]]; then
    echo >&2
    echo "refusing to continue: $NEW_IP already answers ping" >&2
    echo "re-run with --allow-ping-response only if you have confirmed that address is safe to steal" >&2
    exit 1
  fi
fi

echo
echo "Planned replacements:"
echo "  /etc/network/interfaces: $CURRENT_IP -> $NEW_IP"
echo "  /etc/hosts:              $CURRENT_IP -> $NEW_IP"

if [[ "$APPLY" != "1" ]]; then
  echo
  echo "Dry run only. Re-run with --apply or APPLY=1 to make the change."
  exit 0
fi

echo
echo "Applying change on $current_target"
set +e
ssh_current bash -s -- "$CURRENT_IP" "$NEW_IP" "$ROLLBACK_SECONDS" <<'EOF'
set -euo pipefail

CURRENT_IP="$1"
NEW_IP="$2"
ROLLBACK_SECONDS="$3"
BACKUP_DIR="/root/proxmox-reip-$(date +%Y%m%d-%H%M%S)"
METADATA_FILE="/root/proxmox-reip-latest.env"

mkdir -p "$BACKUP_DIR"
cp /etc/network/interfaces "$BACKUP_DIR/interfaces.before"
cp /etc/hosts "$BACKUP_DIR/hosts.before"

python3 - "$CURRENT_IP" "$NEW_IP" "$BACKUP_DIR" <<'PY'
from pathlib import Path
import sys

current_ip, new_ip, backup_dir = sys.argv[1:]
interfaces_path = Path("/etc/network/interfaces")
hosts_path = Path("/etc/hosts")

interfaces_before = interfaces_path.read_text()
hosts_before = hosts_path.read_text()

if current_ip not in interfaces_before:
    raise SystemExit(f"{current_ip} not found in /etc/network/interfaces")
if current_ip not in hosts_before:
    raise SystemExit(f"{current_ip} not found in /etc/hosts")

(Path(backup_dir) / "interfaces.after").write_text(interfaces_before.replace(current_ip, new_ip))
(Path(backup_dir) / "hosts.after").write_text(hosts_before.replace(current_ip, new_ip))
PY

cat > "$BACKUP_DIR/rollback.sh" <<EOF2
#!/usr/bin/env bash
set -euo pipefail
sleep $ROLLBACK_SECONDS
cp "$BACKUP_DIR/interfaces.before" /etc/network/interfaces
cp "$BACKUP_DIR/hosts.before" /etc/hosts
ifreload -a
EOF2
chmod 700 "$BACKUP_DIR/rollback.sh"

nohup "$BACKUP_DIR/rollback.sh" >/root/proxmox-reip-rollback.log 2>&1 < /dev/null &
ROLLBACK_PID="$!"

cat > "$METADATA_FILE" <<EOF2
BACKUP_DIR=$BACKUP_DIR
ROLLBACK_PID=$ROLLBACK_PID
CURRENT_IP=$CURRENT_IP
NEW_IP=$NEW_IP
EOF2

cp "$BACKUP_DIR/interfaces.after" /etc/network/interfaces
cp "$BACKUP_DIR/hosts.after" /etc/hosts
ifreload -a
EOF
apply_rc=$?
set -e

if [[ "$apply_rc" -ne 0 ]]; then
  echo "SSH session dropped during apply. Continuing with verification on $new_target."
fi

echo
echo "Waiting for $new_target to come up"
verified=0
for _ in $(seq 1 12); do
  if ssh_new 'hostname -f >/dev/null 2>&1'; then
    verified=1
    break
  fi
  sleep 5
done

if [[ "$verified" != "1" ]]; then
  echo >&2
  echo "could not reach $new_target after the change" >&2
  echo "the automatic rollback is still armed for ${ROLLBACK_SECONDS}s on the Proxmox host" >&2
  echo "if the host does not recover automatically, use console access and restore the backups under /root/proxmox-reip-*" >&2
  exit 1
fi

echo
echo "New Proxmox network state:"
ssh_new '
  set -euo pipefail
  . /root/proxmox-reip-latest.env
  kill "$ROLLBACK_PID" 2>/dev/null || true
  hostname -f
  ip -4 addr show vmbr0
  ip route
  printf "\n--- /etc/network/interfaces ---\n"
  sed -n "1,160p" /etc/network/interfaces
  printf "\n--- /etc/hosts ---\n"
  sed -n "1,120p" /etc/hosts
  printf "\nbackups: %s\n" "$BACKUP_DIR"
  rm -f /root/proxmox-reip-latest.env
'
