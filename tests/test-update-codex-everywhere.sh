#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATER="$ROOT/scripts/update-codex-everywhere.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

MOCK_BIN="$TEST_ROOT/bin"
MOCK_HOME="$TEST_ROOT/home"
MOCK_LOG="$TEST_ROOT/ssh.log"
MOCK_FAILURES="$TEST_ROOT/failures.log"
MOCK_INSTALLER="$TEST_ROOT/install.sh"
TFVARS="$TEST_ROOT/terraform.tfvars"
SSH_KEY="$TEST_ROOT/mickey"
mkdir -p "$MOCK_BIN" "$MOCK_HOME"
touch "$SSH_KEY" "$MOCK_LOG" "$MOCK_FAILURES"

cat >"$MOCK_INSTALLER" <<'EOF'
#!/bin/sh
set -eu
release="latest"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --release)
      release="$2"
      shift
      ;;
    --help|-h)
      echo "Usage: install.sh [--release VERSION]"
      exit 0
      ;;
  esac
  shift
done
mkdir -p "$CODEX_INSTALL_DIR"
cat >"$CODEX_INSTALL_DIR/codex" <<EOF_INNER
#!/bin/sh
echo "codex-cli $release"
EOF_INNER
chmod 0755 "$CODEX_INSTALL_DIR/codex"
echo "installed Codex $release"
EOF
chmod 0755 "$MOCK_INSTALLER"

cat >"$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
while (($#)); do
  if [[ "$1" == "-o" ]]; then
    output="$2"
    shift 2
    continue
  fi
  shift
done
if [[ -z "$output" ]]; then
  echo "mock curl requires -o" >&2
  exit 2
fi
cp "$MOCK_INSTALLER" "$output"
EOF

cat >"$MOCK_BIN/hostname" <<'EOF'
#!/bin/sh
echo mickey-controller
EOF

cat >"$MOCK_BIN/sleep" <<'EOF'
#!/bin/sh
exit 0
EOF

cat >"$MOCK_BIN/ssh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
args=("$@")
target="${args[${#args[@]}-2]}"
command="${args[${#args[@]}-1]}"

if [[ "$target" == "$MOCK_PVE_HOST" && "$command" == "qm status "* ]]; then
  vmid="${command##* }"
  if [[ "$vmid" == "103" ]]; then
    echo "status: stopped"
  else
    echo "status: running"
  fi
  exit 0
fi

if [[ "$target" == "$MOCK_PVE_HOST" && "$command" == "qm start "* ]]; then
  echo "start:${command##* }" >>"$MOCK_LOG"
  exit 0
fi

if [[ "$target" == "$MOCK_PVE_HOST" && "$command" == "qm shutdown "* ]]; then
  vmid="${command#qm shutdown }"
  vmid="${vmid%% *}"
  echo "stop:$vmid" >>"$MOCK_LOG"
  exit 0
fi

if [[ "$command" == "true" ]]; then
  exit 0
fi

if [[ -n "${MOCK_FAIL_TARGET:-}" && "$target" == "$MOCK_FAIL_TARGET" ]]; then
  echo "$target" >>"$MOCK_FAILURES"
  echo "simulated DNS failure" >&2
  exit 6
fi

target_home="$MOCK_HOME/${target//@/_}"
mkdir -p "$target_home"
HOME="$target_home" sh -c "$command"
EOF
chmod 0755 "$MOCK_BIN/curl" "$MOCK_BIN/hostname" "$MOCK_BIN/sleep" "$MOCK_BIN/ssh"

cat >"$TFVARS" <<'EOF'
vms = {
  "mickey-controller" = {
    clone_template_name = "ubuntu-test"
    vm_id = 100
    lan_ipv4_cidr = "10.0.0.10/24"
  }
  "failbox" = {
    clone_template_name = "ubuntu-test"
    vm_id = 101
    lan_ipv4_cidr = "10.0.0.2/24"
  }
  "afterbox" = {
    clone_template_name = "ubuntu-test"
    vm_id = 102
    lan_ipv4_cidr = "10.0.0.3/24"
  }
  "stoppedbox" = {
    clone_template_name = "ubuntu-test"
    vm_id = 103
    lan_ipv4_cidr = "10.0.0.4/24"
  }
}
EOF

run_updater() {
  local fail_target="$1"
  local lock_file="$2"
  env \
    PATH="$MOCK_BIN:$PATH" \
    HOME="$MOCK_HOME/controller" \
    TFVARS_FILE="$TFVARS" \
    PVE_HOST="root@10.0.0.1" \
    SSH_KEY="$SSH_KEY" \
    CODEX_RELEASE="1.2.3" \
    UPDATE_ATTEMPTS="3" \
    RETRY_DELAY_SECONDS="1" \
    WAIT_FOR_SSH_SECONDS="1" \
    LOCK_FILE="$lock_file" \
    MOCK_INSTALLER="$MOCK_INSTALLER" \
    MOCK_HOME="$MOCK_HOME" \
    MOCK_LOG="$MOCK_LOG" \
    MOCK_FAILURES="$MOCK_FAILURES" \
    MOCK_PVE_HOST="root@10.0.0.1" \
    MOCK_FAIL_TARGET="$fail_target" \
    "$UPDATER"
}

set +e
first_output="$(run_updater "galvanic@10.0.0.2" "$TEST_ROOT/first.lock" 2>&1)"
first_rc=$?
set -e

if [[ "$first_rc" != "1" ]]; then
  printf '%s\n' "$first_output" >&2
  echo "expected the partial-failure run to exit 1, got $first_rc" >&2
  exit 1
fi
grep -Eq '^failbox[[:space:]]+running[[:space:]]+unknown[[:space:]]+unknown[[:space:]]+failed' <<<"$first_output"
grep -Eq '^afterbox[[:space:]]+running[[:space:]]+unknown[[:space:]]+1\.2\.3[[:space:]]+updated' <<<"$first_output"
grep -Eq '^stoppedbox[[:space:]]+stopped[[:space:]]+unknown[[:space:]]+1\.2\.3[[:space:]]+updated' <<<"$first_output"
[[ "$(wc -l <"$MOCK_FAILURES")" == "3" ]]
grep -qx 'start:103' "$MOCK_LOG"
grep -qx 'stop:103' "$MOCK_LOG"
test -x "$MOCK_HOME/galvanic_10.0.0.3/.local/lib/codex/bin/codex"

second_output="$(run_updater "" "$TEST_ROOT/second.lock" 2>&1)"
grep -Eq '^failbox[[:space:]]+running[[:space:]]+unknown[[:space:]]+1\.2\.3[[:space:]]+updated' <<<"$second_output"
grep -Eq '^afterbox[[:space:]]+running[[:space:]]+1\.2\.3[[:space:]]+1\.2\.3[[:space:]]+current' <<<"$second_output"
grep -Eq '^stoppedbox[[:space:]]+stopped[[:space:]]+1\.2\.3[[:space:]]+1\.2\.3[[:space:]]+current' <<<"$second_output"

stops_before="$(grep -c '^stop:103$' "$MOCK_LOG")"
set +e
third_output="$(run_updater "galvanic@10.0.0.4" "$TEST_ROOT/third.lock" 2>&1)"
third_rc=$?
set -e
if [[ "$third_rc" != "1" ]]; then
  printf '%s\n' "$third_output" >&2
  echo "expected the stopped-guest failure run to exit 1, got $third_rc" >&2
  exit 1
fi
grep -Eq '^stoppedbox[[:space:]]+stopped[[:space:]]+unknown[[:space:]]+unknown[[:space:]]+failed' <<<"$third_output"
stops_after="$(grep -c '^stop:103$' "$MOCK_LOG")"
[[ "$stops_after" == "$((stops_before + 1))" ]]

echo "update-codex-everywhere tests passed"
