#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAYBOOK="${1:-}"

if [[ -z "$PLAYBOOK" || $# -lt 2 ]]; then
  echo "usage: run-ansible.sh <playbook> <inventory> [inventory ...]" >&2
  exit 2
fi

for tool in ansible-playbook sops; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "missing required tool: $tool" >&2
    exit 1
  fi
done

shift

SECRETS_FILE="${SECRETS_FILE:-$ROOT/secrets/prod.sops.yaml}"
ANSIBLE_EXTRA_VARS="${ANSIBLE_EXTRA_VARS:-}"
tmp_yaml="$(mktemp)"
cleanup() {
  rm -f "$tmp_yaml"
}
trap cleanup EXIT

sops -d "$SECRETS_FILE" >"$tmp_yaml"
export ANSIBLE_CONFIG="${ANSIBLE_CONFIG:-$ROOT/ansible/ansible.cfg}"

inventory_args=()
for inventory in "$@"; do
  if [[ ! -f "$inventory" ]]; then
    echo "inventory not found: $inventory" >&2
    exit 1
  fi
  inventory_args+=(-i "$inventory")
done

playbook_args=("${inventory_args[@]}" "$PLAYBOOK" -e "secret_vars_file=$tmp_yaml")
if [[ -n "$ANSIBLE_EXTRA_VARS" ]]; then
  playbook_args+=(-e "$ANSIBLE_EXTRA_VARS")
fi

ansible-playbook "${playbook_args[@]}"
