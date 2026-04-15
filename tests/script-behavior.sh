#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
FAKE_BIN="${TMP_DIR}/bin"
CALL_LOG="${TMP_DIR}/calls.log"
TEST_STATE_DIR="${TMP_DIR}/state"
export CALL_LOG
export STATE_DIR="${TEST_STATE_DIR}"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  if [[ -f "${CALL_LOG}" ]]; then
    echo "--- command log ---" >&2
    cat "${CALL_LOG}" >&2
    echo "--- end command log ---" >&2
  fi
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "expected file: $1"
}

assert_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq -- "${expected}" "${file}" || fail "expected ${file} to contain: ${expected}"
}

assert_log_contains() {
  local expected="$1"
  sed 's/\\ / /g; s/\\,/,/g' "${CALL_LOG}" | grep -Fq -- "${expected}" ||
    fail "expected call log to contain: ${expected}"
}

write_fake_bin() {
  mkdir -p "${FAKE_BIN}"

  cat > "${FAKE_BIN}/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'curl %q\n' "$*" >> "${CALL_LOG}"
if [[ "$*" == *"https://factory.talos.dev/schematics"* ]]; then
  printf '{"id":"test-schematic"}'
  exit 0
fi
if [[ "$*" == *"https://factory.talos.dev/image/test-schematic/v1.11.5/metal-amd64.iso"* ]]; then
  out=""
  prev=""
  for arg in "$@"; do
    if [[ "${prev}" == "-o" ]]; then
      out="${arg}"
      break
    fi
    prev="${arg}"
  done
  [[ -n "${out}" ]]
  mkdir -p "$(dirname "${out}")"
  printf 'fake iso\n' > "${out}"
  exit 0
fi
echo "unexpected curl args: $*" >&2
exit 2
SH

  cat > "${FAKE_BIN}/sha256sum" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'sha256sum %q\n' "$*" >> "${CALL_LOG}"
SH

  cat > "${FAKE_BIN}/qemu-img" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'qemu-img %q\n' "$*" >> "${CALL_LOG}"
if [[ "${1:-}" == "create" ]]; then
  file="${4:-}"
  mkdir -p "$(dirname "${file}")"
  printf 'fake disk\n' > "${file}"
fi
SH

  cat > "${FAKE_BIN}/qemu-system-x86_64" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'qemu-system-x86_64 %q\n' "$*" >> "${CALL_LOG}"
pidfile=""
prev=""
for arg in "$@"; do
  if [[ "${prev}" == "-pidfile" ]]; then
    pidfile="${arg}"
    break
  fi
  prev="${arg}"
done
[[ -n "${pidfile}" ]]
mkdir -p "$(dirname "${pidfile}")"
printf '%s\n' "$$" > "${pidfile}"
SH

  cat > "${FAKE_BIN}/kubectl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'kubectl %q\n' "$*" >> "${CALL_LOG}"
SH

cat > "${FAKE_BIN}/talosctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'talosctl %q\n' "$*" >> "${CALL_LOG}"
while (($#)); do
  case "$1" in
    --nodes|--talosconfig|--endpoints|-n|-e)
      shift 2
      ;;
    --server=false|--wait-timeout)
      if [[ "$1" == "--wait-timeout" ]]; then
        shift 2
      else
        shift
      fi
      ;;
    --*)
      shift
      ;;
    *)
      break
      ;;
  esac
done
cmd="${1:-}"
shift || true
case "${cmd}" in
  gen)
    [[ "${1:-}" == "config" ]]
    shift
    out=""
    while (($#)); do
      case "$1" in
        --output)
          out="$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    [[ -n "${out}" ]]
    mkdir -p "${out}"
    cat > "${out}/controlplane.yaml" <<'YAML'
machine:
  install:
    disk: /dev/sda
cluster: {}
YAML
    printf 'fake talosconfig\n' > "${out}/talosconfig"
    ;;
  machineconfig)
    [[ "${1:-}" == "patch" ]]
    shift
    input="$1"
    shift
    out=""
    patch=""
    while (($#)); do
      case "$1" in
        --patch)
          patch="${2#@}"
          shift 2
          ;;
        --output)
          out="$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    [[ -n "${out}" && -n "${patch}" ]]
    cat "${input}" "${patch}" > "${out}"
    ;;
  apply-config|bootstrap|health|kubeconfig|version|service|etcd)
    if [[ "${cmd}" == "kubeconfig" ]]; then
      for arg in "$@"; do
        if [[ "${arg}" == */kubeconfig/config ]]; then
          mkdir -p "$(dirname "${arg}")"
          printf 'fake kubeconfig\n' > "${arg}"
        fi
      done
    fi
    ;;
  validate)
    ;;
  *)
    echo "unexpected talosctl command: ${cmd}" >&2
    exit 2
    ;;
esac
SH

  chmod +x "${FAKE_BIN}"/*
}

write_fake_bin
export PATH="${FAKE_BIN}:${PATH}"
cd "${ROOT_DIR}"

rm -f "${CALL_LOG}"

scripts/prepare-image.sh
assert_file "${TEST_STATE_DIR}/schematic.yaml"
assert_file "${TEST_STATE_DIR}/schematic.id"
assert_file "${TEST_STATE_DIR}/assets/talos-v1.11.5-tailscale-metal-amd64.iso"
assert_contains "${TEST_STATE_DIR}/schematic.yaml" "siderolabs/tailscale"
assert_contains "${TEST_STATE_DIR}/schematic.id" "test-schematic"

TS_AUTHKEY=tskey-auth-test scripts/generate-configs.sh
for node in talos-ts-cp1 talos-ts-cp2 talos-ts-cp3; do
  config="${TEST_STATE_DIR}/talos/generated/${node}.yaml"
  assert_file "${config}"
  assert_contains "${config}" "kind: ExtensionServiceConfig"
  assert_contains "${config}" "TS_AUTHKEY=tskey-auth-test"
  assert_contains "${config}" "TS_HOSTNAME=${node}"
  assert_contains "${config}" "hostname: ${node}"
done
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "validSubnets:"
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "advertisedSubnets:"
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "100.64.0.0/10"

VM_DISPLAY_BACKEND=vnc VM_DISPLAY_DEVICE=VGA VM_DISPLAY_WIDTH= VM_DISPLAY_HEIGHT= scripts/start-vms.sh
for idx in 1 2 3; do
  node="talos-ts-cp${idx}"
  assert_file "${TEST_STATE_DIR}/disks/${node}.qcow2"
  assert_file "${TEST_STATE_DIR}/${node}.pid"
done
assert_log_contains "hostfwd=tcp:127.0.0.1:50001-:50000"
assert_log_contains "hostfwd=tcp:127.0.0.1:64431-:6443"
assert_log_contains "-cpu max"
assert_log_contains "-display vnc=127.0.0.1:1"
assert_log_contains "-display vnc=127.0.0.1:2"
assert_log_contains "-display vnc=127.0.0.1:3"
assert_log_contains "-device VGA"

rm -rf "${TEST_STATE_DIR}/disks" "${TEST_STATE_DIR}"/*.pid
VM_DISPLAY_BACKEND=gtk VM_DISPLAY_DEVICE=VGA VM_DISPLAY_WIDTH= VM_DISPLAY_HEIGHT= scripts/start-vms.sh
assert_log_contains "-display gtk,zoom-to-fit=on,show-menubar=on"

scripts/apply-configs.sh
assert_log_contains "apply-config"
assert_log_contains "127.0.0.1:50001"
assert_log_contains "${TEST_STATE_DIR}/talos/generated/talos-ts-cp1.yaml"

scripts/bootstrap.sh
assert_file "${TEST_STATE_DIR}/kubeconfig/config"
assert_log_contains "bootstrap"
assert_log_contains "kubeconfig"

scripts/validate.sh
assert_log_contains "service ext-tailscale"
assert_log_contains "etcd members"
assert_log_contains "kubectl get nodes -o wide"
assert_log_contains "kubectl apply -f"
assert_log_contains "curl -fsS http://tailnet-smoke.default.svc.cluster.local/"

echo "script behavior tests passed"
