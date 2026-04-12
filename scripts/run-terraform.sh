#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTION="${1:-}"

if [[ -z "$ACTION" ]]; then
  echo "usage: run-terraform.sh <plan|apply|destroy|...>" >&2
  exit 2
fi

if [[ "$ACTION" == "init" ]]; then
  terraform -chdir="$ROOT/terraform" init "${@:2}"
  exit $?
fi

for tool in terraform sops python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "missing required tool: $tool" >&2
    exit 1
  fi
done

SECRETS_FILE="${SECRETS_FILE:-$ROOT/secrets/prod.sops.yaml}"
TFVARS_FILE="${TFVARS_FILE:-$ROOT/envs/prod/terraform.tfvars}"

tmp_yaml="$(mktemp)"
tmp_json="$(mktemp --suffix=.tfvars.json)"
cleanup() {
  rm -f "$tmp_yaml" "$tmp_json"
}
trap cleanup EXIT

sops -d "$SECRETS_FILE" >"$tmp_yaml"
python3 "$ROOT/scripts/render_tfvars.py" "$tmp_yaml" >"$tmp_json"

terraform -chdir="$ROOT/terraform" "$ACTION" \
  -var-file="$TFVARS_FILE" \
  -var-file="$tmp_json" \
  "${@:2}"
