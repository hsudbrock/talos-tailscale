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
if [[ "$*" == *"https://raw.githubusercontent.com/argoproj/argo-cd/v3.3.6/manifests/install.yaml"* ]]; then
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
  printf 'apiVersion: v1\nkind: List\nitems: []\n' > "${out}"
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

  cat > "${FAKE_BIN}/k9s" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'k9s KUBECONFIG=%q args=%q\n' "${KUBECONFIG:-}" "$*" >> "${CALL_LOG}"
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
    cat > "${out}/worker.yaml" <<'YAML'
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
export CONTROL_PLANE_NODE_NAMES="talos-ts-cp1 talos-ts-cp2 talos-ts-cp3"
export WORKER_NODE_NAMES="talos-ts-worker1 talos-ts-worker2 talos-ts-worker3"
export NODE_NAMES="${CONTROL_PLANE_NODE_NAMES} ${WORKER_NODE_NAMES}"

scripts/prepare-image.sh
assert_file "${TEST_STATE_DIR}/schematic.yaml"
assert_file "${TEST_STATE_DIR}/schematic.id"
assert_file "${TEST_STATE_DIR}/assets/talos-v1.11.5-tailscale-metal-amd64.iso"
assert_contains "${TEST_STATE_DIR}/schematic.yaml" "siderolabs/tailscale"
assert_contains "${TEST_STATE_DIR}/schematic.id" "test-schematic"

TS_AUTHKEY=tskey-auth-test scripts/generate-configs.sh
for node in talos-ts-cp1 talos-ts-cp2 talos-ts-cp3 talos-ts-worker1 talos-ts-worker2 talos-ts-worker3; do
  config="${TEST_STATE_DIR}/talos/generated/${node}.yaml"
  assert_file "${config}"
  assert_contains "${config}" "kind: ExtensionServiceConfig"
  assert_contains "${config}" "TS_AUTHKEY=tskey-auth-test"
  assert_contains "${config}" "TS_HOSTNAME=${node}"
  assert_contains "${config}" "hostname: ${node}"
done
assert_log_contains "--output-types controlplane,worker,talosconfig"
assert_log_contains "--config-patch-control-plane @${TEST_STATE_DIR}/patches/common.yaml"
assert_log_contains "--config-patch-control-plane @${TEST_STATE_DIR}/patches/control-plane.yaml"
assert_log_contains "--config-patch-worker @${TEST_STATE_DIR}/patches/common.yaml"
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "validSubnets:"
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "100.64.0.0/10"
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "flannel:"
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "--iface=tailscale0"
assert_contains "${TEST_STATE_DIR}/patches/control-plane.yaml" "advertisedSubnets:"
assert_contains "${TEST_STATE_DIR}/patches/control-plane.yaml" "100.64.0.0/10"
assert_log_contains "--install-disk /dev/vda"

VM_DISPLAY_BACKEND=vnc VM_DISPLAY_DEVICE=VGA VM_DISPLAY_WIDTH= VM_DISPLAY_HEIGHT= scripts/start-vms.sh
for node in talos-ts-cp1 talos-ts-cp2 talos-ts-cp3 talos-ts-worker1 talos-ts-worker2 talos-ts-worker3; do
  assert_file "${TEST_STATE_DIR}/disks/${node}.qcow2"
  assert_file "${TEST_STATE_DIR}/${node}.pid"
done
assert_log_contains "hostfwd=tcp:127.0.0.1:50001-:50000"
assert_log_contains "hostfwd=tcp:127.0.0.1:64431-:6443"
assert_log_contains "-boot order=cd"
assert_log_contains "-cpu max"
assert_log_contains "-display vnc=127.0.0.1:1"
assert_log_contains "-display vnc=127.0.0.1:2"
assert_log_contains "-display vnc=127.0.0.1:3"
assert_log_contains "-display vnc=127.0.0.1:4"
assert_log_contains "-display vnc=127.0.0.1:5"
assert_log_contains "-display vnc=127.0.0.1:6"
assert_log_contains "-device VGA"

rm -rf "${TEST_STATE_DIR}/disks" "${TEST_STATE_DIR}"/*.pid
VM_DISPLAY_BACKEND=gtk VM_DISPLAY_DEVICE=VGA VM_DISPLAY_WIDTH= VM_DISPLAY_HEIGHT= scripts/start-vms.sh
assert_log_contains "-display gtk,zoom-to-fit=on,show-menubar=on"
assert_log_contains "-daemonize -pidfile"
for node in talos-ts-cp1 talos-ts-cp2 talos-ts-cp3 talos-ts-worker1 talos-ts-worker2 talos-ts-worker3; do
  assert_file "${TEST_STATE_DIR}/${node}.pid"
  assert_file "${TEST_STATE_DIR}/logs/${node}.qemu.log"
done

scripts/apply-configs.sh
assert_log_contains "apply-config"
assert_log_contains "127.0.0.1:50001"
assert_log_contains "${TEST_STATE_DIR}/talos/generated/talos-ts-cp1.yaml"
assert_log_contains "127.0.0.1:50004"
assert_log_contains "${TEST_STATE_DIR}/talos/generated/talos-ts-worker1.yaml"
assert_log_contains "127.0.0.1:50005"
assert_log_contains "${TEST_STATE_DIR}/talos/generated/talos-ts-worker2.yaml"
assert_log_contains "127.0.0.1:50006"
assert_log_contains "${TEST_STATE_DIR}/talos/generated/talos-ts-worker3.yaml"

scripts/bootstrap.sh
assert_file "${TEST_STATE_DIR}/kubeconfig/config"
assert_log_contains "--endpoints 127.0.0.1:50001 --nodes 127.0.0.1 version"
assert_log_contains "--endpoints 127.0.0.1:50001 --nodes 127.0.0.1 bootstrap"
assert_log_contains "--endpoints 127.0.0.1:50001 --nodes 127.0.0.1 kubeconfig"
assert_log_contains "bootstrap"
assert_log_contains "kubeconfig"

PATH="${FAKE_BIN}:${PATH}" STATE_DIR="${TEST_STATE_DIR}" make --no-print-directory k9s
assert_log_contains "k9s KUBECONFIG=${TEST_STATE_DIR}/kubeconfig/config args=''"

ARGOCD_REPO_URL=https://github.com/example/talos-tailscale.git \
ARGOCD_TARGET_REVISION=main \
ARGOCD_ROOT_PATH=gitops/clusters/talos-tailnet-local/root \
scripts/bootstrap-argocd.sh
assert_file "${TEST_STATE_DIR}/argocd/namespace.yaml"
assert_file "${TEST_STATE_DIR}/argocd/install-v3.3.6.yaml"
assert_file "${TEST_STATE_DIR}/argocd/root-application.yaml"
assert_contains "${TEST_STATE_DIR}/argocd/namespace.yaml" "name: argocd"
assert_contains "${TEST_STATE_DIR}/argocd/root-application.yaml" "repoURL: https://github.com/example/talos-tailscale.git"
assert_contains "${TEST_STATE_DIR}/argocd/root-application.yaml" "targetRevision: main"
assert_contains "${TEST_STATE_DIR}/argocd/root-application.yaml" "path: gitops/clusters/talos-tailnet-local/root"
assert_log_contains "curl -fsSL https://raw.githubusercontent.com/argoproj/argo-cd/v3.3.6/manifests/install.yaml -o ${TEST_STATE_DIR}/argocd/install-v3.3.6.yaml"
assert_log_contains "kubectl apply -f ${TEST_STATE_DIR}/argocd/namespace.yaml"
assert_log_contains "kubectl apply -n argocd --server-side --force-conflicts -f ${TEST_STATE_DIR}/argocd/install-v3.3.6.yaml"
assert_log_contains "kubectl rollout status deployment/argocd-server --timeout=5m -n argocd"
assert_log_contains "kubectl rollout status statefulset/argocd-application-controller --timeout=5m -n argocd"
assert_log_contains "kubectl apply -f ${TEST_STATE_DIR}/argocd/root-application.yaml"

scripts/validate.sh
assert_log_contains "--endpoints talos-ts-cp1 --nodes talos-ts-cp1 version"
assert_log_contains "--endpoints talos-ts-cp2 --nodes talos-ts-cp2 version"
assert_log_contains "--endpoints talos-ts-cp3 --nodes talos-ts-cp3 version"
assert_log_contains "--endpoints talos-ts-worker1 --nodes talos-ts-worker1 version"
assert_log_contains "--endpoints talos-ts-worker2 --nodes talos-ts-worker2 version"
assert_log_contains "--endpoints talos-ts-worker3 --nodes talos-ts-worker3 version"
assert_log_contains "service ext-tailscale"
assert_log_contains "etcd members"
assert_log_contains "kubectl get nodes -o wide"
assert_log_contains "kubectl apply -f"
assert_log_contains "kubectl delete -f"
assert_log_contains "--ignore-not-found"
assert_contains "${ROOT_DIR}/config/kubernetes/cross-node-smoke.yaml" "replicas: 2"
if grep -Fq "node-role.kubernetes.io/control-plane" "${ROOT_DIR}/config/kubernetes/cross-node-smoke.yaml"; then
  fail "smoke workload should schedule on workers without control-plane tolerations"
fi
if sed 's/\\ / /g; s/\\,/,/g' "${CALL_LOG}" | grep -Fq -- "--overrides="; then
  fail "validation curl pod should schedule on workers without control-plane tolerations"
fi
assert_log_contains "curl -fsS http://tailnet-smoke.default.svc.cluster.local/"

make -n logs-tailscale > "${TMP_DIR}/make-logs-tailscale.txt"
assert_contains "${TMP_DIR}/make-logs-tailscale.txt" "127.0.0.1:50001"
assert_contains "${TMP_DIR}/make-logs-tailscale.txt" "127.0.0.1:50002"
assert_contains "${TMP_DIR}/make-logs-tailscale.txt" "127.0.0.1:50003"
assert_contains "${TMP_DIR}/make-logs-tailscale.txt" "127.0.0.1:50004"
assert_contains "${TMP_DIR}/make-logs-tailscale.txt" "127.0.0.1:50005"
assert_contains "${TMP_DIR}/make-logs-tailscale.txt" "127.0.0.1:50006"
assert_contains "${TMP_DIR}/make-logs-tailscale.txt" "logs ext-tailscale --tail 120"

make -n clean-disks > "${TMP_DIR}/make-clean-disks.txt"
assert_contains "${TMP_DIR}/make-clean-disks.txt" "scripts/stop-vms.sh"
assert_contains "${TMP_DIR}/make-clean-disks.txt" "rm -rf .state/disks"

make -n argocd-status > "${TMP_DIR}/make-argocd-status.txt"
assert_contains "${TMP_DIR}/make-argocd-status.txt" "kubectl get pods,applications -n argocd"
assert_contains "${TMP_DIR}/make-argocd-status.txt" "rollout status deployment/argocd-server"
assert_contains "${TMP_DIR}/make-argocd-status.txt" "rollout status statefulset/argocd-application-controller"

make -n argocd-sync > "${TMP_DIR}/make-argocd-sync.txt"
assert_contains "${TMP_DIR}/make-argocd-sync.txt" "annotate application talos-tailnet-local-root argocd.argoproj.io/refresh=hard --overwrite"
assert_contains "${TMP_DIR}/make-argocd-sync.txt" "patch application talos-tailnet-local-root --type merge"
assert_contains "${TMP_DIR}/make-argocd-sync.txt" '"operation":{"sync":{"revision":"main","prune":true,"syncOptions":["CreateNamespace=true"]}}'
assert_contains "${TMP_DIR}/make-argocd-sync.txt" "get application talos-tailnet-local-root"

make -n argocd-password > "${TMP_DIR}/make-argocd-password.txt"
assert_contains "${TMP_DIR}/make-argocd-password.txt" "argocd-initial-admin-secret"
assert_contains "${TMP_DIR}/make-argocd-password.txt" "base64 -d"

make -n argocd-ui > "${TMP_DIR}/make-argocd-ui.txt"
assert_contains "${TMP_DIR}/make-argocd-ui.txt" "port-forward svc/argocd-server 8080:443"

make help > "${TMP_DIR}/make-help.txt"
assert_contains "${TMP_DIR}/make-help.txt" "make argocd     Install Argo CD and apply the root Application"
assert_contains "${TMP_DIR}/make-help.txt" "make argocd-status Show Argo CD pods and rollout status"
assert_contains "${TMP_DIR}/make-help.txt" "make argocd-sync Trigger a hard refresh and sync of the root Application"
assert_contains "${TMP_DIR}/make-help.txt" "make argocd-ui  Port-forward the Argo CD API/UI to localhost:8080"
assert_contains "${TMP_DIR}/make-help.txt" "make argocd-password Print the initial Argo CD admin password"

echo "script behavior tests passed"
