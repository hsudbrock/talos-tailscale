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

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -Fq -- "${unexpected}" "${file}"; then
    fail "expected ${file} not to contain: ${unexpected}"
  fi
}

assert_log_contains() {
  local expected="$1"
  sed 's/\\ / /g; s/\\,/,/g' "${CALL_LOG}" | grep -Fq -- "${expected}" ||
    fail "expected call log to contain: ${expected}"
}

assert_log_not_contains() {
  local unexpected="$1"
  if sed 's/\\ / /g; s/\\,/,/g' "${CALL_LOG}" | grep -Fq -- "${unexpected}"; then
    fail "expected call log not to contain: ${unexpected}"
  fi
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
if [[ "$*" == *"https://factory.talos.dev/image/test-schematic/"*"/metal-amd64.iso"* ]]; then
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
orig_args=("$@")
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
---
apiVersion: v1alpha1
kind: HostnameConfig
auto: stable
YAML
    cat > "${out}/worker.yaml" <<'YAML'
machine:
  install:
    disk: /dev/sda
cluster: {}
---
apiVersion: v1alpha1
kind: HostnameConfig
auto: stable
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
    if [[ "${cmd}" == "apply-config" && "${FAKE_TALOSCTL_APPLY_REQUIRE_AUTH:-0}" == "1" ]]; then
      for arg in "${orig_args[@]}"; do
        if [[ "${arg}" == "--insecure" ]]; then
          echo 'error applying new configuration: rpc error: code = Unavailable desc = connection error: desc = "error reading server preface: remote error: tls: certificate required"' >&2
          exit 1
        fi
      done
    fi
    if [[ "${cmd}" == "kubeconfig" ]]; then
      for arg in "$@"; do
        if [[ "${arg}" == */kubeconfig/config ]]; then
          mkdir -p "$(dirname "${arg}")"
          printf 'fake kubeconfig\n' > "${arg}"
        fi
      done
    fi
    ;;
  logs)
    service_name="${1:-}"
    case "${service_name}" in
      machined)
        printf 'old boot warning: StaticEndpointController lookup talos-ts-cp1 on 127.0.0.53:53: no such host\n'
        for i in $(seq 1 120); do
          printf 'machined info line %s\n' "${i}"
        done
        ;;
      ext-tailscale)
        for i in $(seq 1 90); do
          printf 'tailscale info line %s\n' "${i}"
        done
        printf 'health(warnable=dns-set-os-config-failed): error: writing to "/etc/resolv.pre-tailscale-backup.conf": read-only file system\n'
        ;;
      *)
        ;;
    esac
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
export TAILSCALE_SEARCH_DOMAIN="tail4d7760.ts.net"
export NODE_NAME_SUFFIX=""
export LONGHORN_DISK_SELECTOR='disk.dev_path == "/dev/vdb"'
export LONGHORN_VOLUME_MAX_SIZE="16GiB"

scripts/prepare-image.sh
assert_file "${TEST_STATE_DIR}/schematic.yaml"
assert_file "${TEST_STATE_DIR}/schematic.id"
compgen -G "${TEST_STATE_DIR}/assets/talos-v*-tailscale-metal-amd64.iso" >/dev/null ||
  fail "expected downloaded Talos ISO asset"
assert_contains "${TEST_STATE_DIR}/schematic.yaml" "siderolabs/tailscale"
assert_contains "${TEST_STATE_DIR}/schematic.yaml" "siderolabs/iscsi-tools"
assert_contains "${TEST_STATE_DIR}/schematic.yaml" "siderolabs/util-linux-tools"
assert_contains "${TEST_STATE_DIR}/schematic.id" "test-schematic"

TS_AUTHKEY=tskey-auth-test scripts/generate-configs.sh
for node in talos-ts-cp1 talos-ts-cp2 talos-ts-cp3 talos-ts-worker1 talos-ts-worker2 talos-ts-worker3; do
  config="${TEST_STATE_DIR}/talos/generated/${node}.yaml"
  assert_file "${config}"
  assert_contains "${config}" "kind: ExtensionServiceConfig"
  assert_contains "${config}" "kind: HostnameConfig"
  assert_contains "${config}" "TS_AUTHKEY=tskey-auth-test"
  assert_contains "${config}" "TS_HOSTNAME=${node}"
  assert_contains "${config}" "TS_ACCEPT_DNS=false"
  assert_contains "${config}" "hostname: ${node}"
  assert_not_contains "${config}" "    hostname: ${node}"
  assert_not_contains "${config}" "auto: stable"
done
for node in talos-ts-cp1 talos-ts-cp2 talos-ts-cp3; do
  config="${TEST_STATE_DIR}/talos/generated/${node}.yaml"
  assert_not_contains "${config}" "kind: UserVolumeConfig"
  assert_not_contains "${config}" "/var/mnt/longhorn"
done
for node in talos-ts-worker1 talos-ts-worker2 talos-ts-worker3; do
  config="${TEST_STATE_DIR}/talos/generated/${node}.yaml"
  assert_contains "${config}" "kind: UserVolumeConfig"
  assert_contains "${config}" "name: longhorn"
  assert_contains "${config}" "match: disk.dev_path == \"/dev/vdb\""
  assert_contains "${config}" "maxSize: 16GiB"
done
assert_log_contains "--output-types controlplane,worker,talosconfig"
assert_log_contains "--config-patch-control-plane @${TEST_STATE_DIR}/patches/common.yaml"
assert_log_contains "--config-patch-control-plane @${TEST_STATE_DIR}/patches/control-plane.yaml"
assert_log_contains "--config-patch-worker @${TEST_STATE_DIR}/patches/common.yaml"
assert_log_contains "--config-patch-worker @${TEST_STATE_DIR}/patches/worker.yaml"
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "validSubnets:"
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "100.64.0.0/10"
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "flannel:"
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "--iface=tailscale0"
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "kind: ResolverConfig"
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "address: 100.100.100.100"
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "address: 9.9.9.9"
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "address: 1.1.1.1"
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "address: 8.8.8.8"
assert_contains "${TEST_STATE_DIR}/patches/common.yaml" "tail4d7760.ts.net"
assert_contains "${TEST_STATE_DIR}/patches/control-plane.yaml" "advertisedSubnets:"
assert_contains "${TEST_STATE_DIR}/patches/control-plane.yaml" "100.64.0.0/10"
assert_contains "${TEST_STATE_DIR}/patches/worker.yaml" "destination: /var/mnt/longhorn"
assert_contains "${TEST_STATE_DIR}/patches/worker.yaml" "source: /var/mnt/longhorn"
assert_contains "${TEST_STATE_DIR}/patches/worker.yaml" "rshared"
assert_log_contains "--install-disk /dev/vda"

SUFFIX_STATE_DIR="${TMP_DIR}/state-suffix"
STATE_DIR="${SUFFIX_STATE_DIR}" scripts/prepare-image.sh
NODE_NAME_SUFFIX=random STATE_DIR="${SUFFIX_STATE_DIR}" TS_AUTHKEY=tskey-auth-test scripts/generate-configs.sh
suffix="$(<"${SUFFIX_STATE_DIR}/node-name-suffix")"
assert_file "${SUFFIX_STATE_DIR}/node-name-suffix"
assert_file "${SUFFIX_STATE_DIR}/talos/generated/talos-ts-cp1${suffix}.yaml"
assert_contains "${SUFFIX_STATE_DIR}/talos/generated/talos-ts-cp1${suffix}.yaml" "TS_HOSTNAME=talos-ts-cp1${suffix}"
assert_contains "${SUFFIX_STATE_DIR}/talos/generated/talos-ts-cp1${suffix}.yaml" "hostname: talos-ts-cp1${suffix}"
assert_log_contains "gen config talos-tailnet-local https://talos-ts-cp1${suffix}:6443"

NODE_NAME_SUFFIX=random STATE_DIR="${SUFFIX_STATE_DIR}" TS_AUTHKEY=tskey-auth-test scripts/generate-configs.sh
assert_contains "${SUFFIX_STATE_DIR}/node-name-suffix" "${suffix}"

VM_DISPLAY_BACKEND=vnc VM_DISPLAY_DEVICE=VGA VM_DISPLAY_WIDTH= VM_DISPLAY_HEIGHT= scripts/start-vms.sh
for node in talos-ts-cp1 talos-ts-cp2 talos-ts-cp3 talos-ts-worker1 talos-ts-worker2 talos-ts-worker3; do
  assert_file "${TEST_STATE_DIR}/disks/${node}.qcow2"
  assert_file "${TEST_STATE_DIR}/${node}.pid"
done
for node in talos-ts-worker1 talos-ts-worker2 talos-ts-worker3; do
  assert_file "${TEST_STATE_DIR}/disks/${node}-data.qcow2"
done
for node in talos-ts-cp1 talos-ts-cp2 talos-ts-cp3; do
  [[ ! -f "${TEST_STATE_DIR}/disks/${node}-data.qcow2" ]] || fail "expected no worker data disk for ${node}"
done
assert_log_contains "hostfwd=tcp:127.0.0.1:50001-:50000"
assert_log_contains "hostfwd=tcp:127.0.0.1:64431-:6443"
assert_log_contains "-boot order=cd"
assert_log_contains "-cpu max"
assert_log_contains "file=${TEST_STATE_DIR}/disks/talos-ts-worker1-data.qcow2,format=qcow2,if=virtio"
assert_log_not_contains "file=${TEST_STATE_DIR}/disks/talos-ts-cp1-data.qcow2,format=qcow2,if=virtio"
assert_log_contains "-display vnc=127.0.0.1:1"
assert_log_contains "-display vnc=127.0.0.1:2"
assert_log_contains "-display vnc=127.0.0.1:3"
assert_log_contains "-display vnc=127.0.0.1:4"
assert_log_contains "-display vnc=127.0.0.1:5"
assert_log_contains "-display vnc=127.0.0.1:6"
assert_log_contains "-device VGA"

restart_pid_before="$(<"${TEST_STATE_DIR}/talos-ts-worker1.pid")"
NODE=talos-ts-worker1 VM_DISPLAY_BACKEND=vnc VM_DISPLAY_DEVICE=VGA VM_DISPLAY_WIDTH= VM_DISPLAY_HEIGHT= scripts/restart-node.sh
restart_pid_after="$(<"${TEST_STATE_DIR}/talos-ts-worker1.pid")"
[[ "${restart_pid_before}" != "${restart_pid_after}" ]] || fail "expected restart-node to replace worker pid"
assert_file "${TEST_STATE_DIR}/talos-ts-worker1.pid"

if NODE=talos-ts-missing scripts/restart-node.sh >"${TMP_DIR}/restart-node.out" 2>"${TMP_DIR}/restart-node.err"; then
  fail "expected restart-node to fail for an unknown node"
fi
assert_contains "${TMP_DIR}/restart-node.err" "unknown node: talos-ts-missing"

if scripts/restart-node.sh >"${TMP_DIR}/restart-node-missing.out" 2>"${TMP_DIR}/restart-node-missing.err"; then
  fail "expected restart-node to fail when NODE is missing"
fi
assert_contains "${TMP_DIR}/restart-node-missing.err" "missing NODE; use NODE=<node-name>"

rm -rf "${TEST_STATE_DIR}/disks" "${TEST_STATE_DIR}"/*.pid
VM_DISPLAY_BACKEND=gtk VM_DISPLAY_DEVICE=VGA VM_DISPLAY_WIDTH= VM_DISPLAY_HEIGHT= scripts/start-vms.sh
assert_log_contains "-display gtk,zoom-to-fit=on,show-menubar=on"
assert_log_contains "-daemonize -pidfile"
for node in talos-ts-cp1 talos-ts-cp2 talos-ts-cp3 talos-ts-worker1 talos-ts-worker2 talos-ts-worker3; do
  assert_file "${TEST_STATE_DIR}/${node}.pid"
  assert_file "${TEST_STATE_DIR}/logs/${node}.qemu.log"
done

WAIT_TALOS_PROBE=version scripts/apply-configs.sh
assert_log_contains "apply-config"
assert_log_contains "127.0.0.1:50001"
assert_log_contains "${TEST_STATE_DIR}/talos/generated/talos-ts-cp1.yaml"
assert_log_contains "127.0.0.1:50004"
assert_log_contains "${TEST_STATE_DIR}/talos/generated/talos-ts-worker1.yaml"
assert_log_contains "127.0.0.1:50005"
assert_log_contains "${TEST_STATE_DIR}/talos/generated/talos-ts-worker2.yaml"
assert_log_contains "127.0.0.1:50006"
assert_log_contains "${TEST_STATE_DIR}/talos/generated/talos-ts-worker3.yaml"

: > "${CALL_LOG}"
FAKE_TALOSCTL_APPLY_REQUIRE_AUTH=1 WAIT_TALOS_PROBE=version scripts/apply-configs.sh
assert_log_contains "--nodes 127.0.0.1:50001 --file ${TEST_STATE_DIR}/talos/generated/talos-ts-cp1.yaml"
assert_log_contains "--talosconfig ${TEST_STATE_DIR}/talos/generated/talosconfig --endpoints 127.0.0.1:50001 --nodes talos-ts-cp1 --file ${TEST_STATE_DIR}/talos/generated/talos-ts-cp1.yaml"
assert_log_contains "--talosconfig ${TEST_STATE_DIR}/talos/generated/talosconfig --endpoints 127.0.0.1:50001 --nodes talos-ts-worker1 --file ${TEST_STATE_DIR}/talos/generated/talos-ts-worker1.yaml"

WAIT_TALOS_PROBE=version scripts/wait-talos-apis.sh

scripts/bootstrap.sh
assert_file "${TEST_STATE_DIR}/kubeconfig/config"
assert_log_contains "--endpoints 127.0.0.1:50001 --nodes 127.0.0.1 version"
assert_log_contains "--endpoints 127.0.0.1:50001 --nodes 127.0.0.1 bootstrap"
assert_log_contains "--endpoints 127.0.0.1:50001 --nodes 127.0.0.1 kubeconfig"
assert_log_contains "bootstrap"
assert_log_contains "kubeconfig"

WAIT_TALOS_PROBE=version scripts/bootstrap-from-scratch.sh
assert_log_contains "apply-config --insecure --nodes 127.0.0.1:50001"

printf '%s\n' '-oldsuffix' > "${SUFFIX_STATE_DIR}/node-name-suffix"
WAIT_TALOS_PROBE=version NODE_NAME_SUFFIX=random STATE_DIR="${SUFFIX_STATE_DIR}" scripts/bootstrap-from-scratch.sh
new_suffix="$(<"${SUFFIX_STATE_DIR}/node-name-suffix")"
[[ "${new_suffix}" != "-oldsuffix" ]] || fail "expected bootstrap-from-scratch to refresh the random node suffix"
assert_file "${SUFFIX_STATE_DIR}/talos/generated/talos-ts-cp1${new_suffix}.yaml"
assert_log_contains "talosctl gen config talos-tailnet-local https://talos-ts-cp1${new_suffix}:6443 --output ${SUFFIX_STATE_DIR}/talos/base"
assert_log_not_contains "talosctl gen config talos-tailnet-local https://talos-ts-cp1-oldsuffix:6443 --output ${SUFFIX_STATE_DIR}/talos/base"

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
assert_log_contains "kubectl wait --for=jsonpath=\\{.status.phase\\}=Succeeded pod/tailnet-curl --timeout=2m"
assert_log_contains "kubectl logs tailnet-curl"
assert_contains "${ROOT_DIR}/config/kubernetes/cross-node-smoke.yaml" "replicas: 2"
if grep -Fq "node-role.kubernetes.io/control-plane" "${ROOT_DIR}/config/kubernetes/cross-node-smoke.yaml"; then
  fail "smoke workload should schedule on workers without control-plane tolerations"
fi
if sed 's/\\ / /g; s/\\,/,/g' "${CALL_LOG}" | grep -Fq -- "kubectl run tailnet-curl"; then
  fail "validation should use a PodSecurity-compliant pod manifest instead of kubectl run"
fi

make -n logs-tailscale > "${TMP_DIR}/make-logs-tailscale.txt"
assert_contains "${TMP_DIR}/make-logs-tailscale.txt" "127.0.0.1:50001"
assert_contains "${TMP_DIR}/make-logs-tailscale.txt" "127.0.0.1:50002"
assert_contains "${TMP_DIR}/make-logs-tailscale.txt" "127.0.0.1:50003"
assert_contains "${TMP_DIR}/make-logs-tailscale.txt" "127.0.0.1:50004"
assert_contains "${TMP_DIR}/make-logs-tailscale.txt" "127.0.0.1:50005"
assert_contains "${TMP_DIR}/make-logs-tailscale.txt" "127.0.0.1:50006"
assert_contains "${TMP_DIR}/make-logs-tailscale.txt" "logs ext-tailscale --tail 120"

scripts/logs-audit.sh > "${TMP_DIR}/logs-audit.out"
assert_contains "${TMP_DIR}/logs-audit.out" "NODE                     SERVICE        PATTERN          STATE"
assert_contains "${TMP_DIR}/logs-audit.out" "talos-ts-cp1             machined       endpoint-dns     historical"
assert_contains "${TMP_DIR}/logs-audit.out" "talos-ts-cp1             ext-tailscale  dns-write        recurring"

make -n logs-audit > "${TMP_DIR}/make-logs-audit.txt"
assert_contains "${TMP_DIR}/make-logs-audit.txt" "scripts/logs-audit.sh"

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

make -n longhorn-status > "${TMP_DIR}/make-longhorn-status.txt"
assert_contains "${TMP_DIR}/make-longhorn-status.txt" "kubectl get pods -n longhorn-system"
assert_contains "${TMP_DIR}/make-longhorn-status.txt" "kubectl -n argocd get application longhorn"
assert_contains "${TMP_DIR}/make-longhorn-status.txt" "rollout status deployment/longhorn-ui"
assert_contains "${TMP_DIR}/make-longhorn-status.txt" "rollout status daemonset/longhorn-manager"
assert_contains "${TMP_DIR}/make-longhorn-status.txt" "rollout status deployment/longhorn-driver-deployer"

make -n longhorn-sync > "${TMP_DIR}/make-longhorn-sync.txt"
assert_contains "${TMP_DIR}/make-longhorn-sync.txt" "annotate application longhorn argocd.argoproj.io/refresh=hard --overwrite"
assert_contains "${TMP_DIR}/make-longhorn-sync.txt" "patch application longhorn --type merge"
assert_contains "${TMP_DIR}/make-longhorn-sync.txt" '"operation":{"sync":{"prune":true,"syncOptions":["CreateNamespace=true"]}}'
assert_contains "${TMP_DIR}/make-longhorn-sync.txt" "get application longhorn"

make -n longhorn-ui > "${TMP_DIR}/make-longhorn-ui.txt"
assert_contains "${TMP_DIR}/make-longhorn-ui.txt" "port-forward svc/longhorn-frontend 8081:80"

assert_contains "${ROOT_DIR}/gitops/clusters/talos-tailnet-local/root/kustomization.yaml" "platform-longhorn-namespace.yaml"
assert_contains "${ROOT_DIR}/gitops/clusters/talos-tailnet-local/root/kustomization.yaml" "platform-longhorn.yaml"
assert_contains "${ROOT_DIR}/gitops/clusters/talos-tailnet-local/root/platform-longhorn-namespace.yaml" "name: longhorn-system"
assert_contains "${ROOT_DIR}/gitops/clusters/talos-tailnet-local/root/platform-longhorn-namespace.yaml" "pod-security.kubernetes.io/enforce: privileged"
assert_contains "${ROOT_DIR}/gitops/clusters/talos-tailnet-local/root/platform-longhorn.yaml" "name: longhorn"
assert_contains "${ROOT_DIR}/gitops/clusters/talos-tailnet-local/root/platform-longhorn.yaml" "repoURL: https://charts.longhorn.io"
assert_contains "${ROOT_DIR}/gitops/clusters/talos-tailnet-local/root/platform-longhorn.yaml" "targetRevision: v1.11.1"
assert_contains "${ROOT_DIR}/gitops/clusters/talos-tailnet-local/root/platform-longhorn.yaml" "namespace: longhorn-system"
assert_contains "${ROOT_DIR}/gitops/clusters/talos-tailnet-local/root/platform-longhorn.yaml" "defaultDataPath: /var/mnt/longhorn"
assert_contains "${ROOT_DIR}/gitops/clusters/talos-tailnet-local/root/platform-longhorn.yaml" "defaultClassReplicaCount: 1"
assert_contains "${ROOT_DIR}/gitops/clusters/talos-tailnet-local/root/platform-longhorn.yaml" "jobEnabled: false"

make help > "${TMP_DIR}/make-help.txt"
assert_contains "${TMP_DIR}/make-help.txt" "make argocd     Install Argo CD and apply the root Application"
assert_contains "${TMP_DIR}/make-help.txt" "make restart-node NODE=talos-ts-worker1 Restart a single VM by node name"
assert_contains "${TMP_DIR}/make-help.txt" "make bootstrap-from-scratch Rebuild disks, start VMs, apply configs, and bootstrap"
assert_contains "${TMP_DIR}/make-help.txt" "make argocd-status Show Argo CD pods and rollout status"
assert_contains "${TMP_DIR}/make-help.txt" "make argocd-sync Trigger a hard refresh and sync of the root Application"
assert_contains "${TMP_DIR}/make-help.txt" "make argocd-ui  Port-forward the Argo CD API/UI to localhost:8080"
assert_contains "${TMP_DIR}/make-help.txt" "make argocd-password Print the initial Argo CD admin password"
assert_contains "${TMP_DIR}/make-help.txt" "make longhorn-status Show Longhorn pods and rollout status"
assert_contains "${TMP_DIR}/make-help.txt" "make longhorn-sync Trigger a hard refresh and sync of the Longhorn Application"
assert_contains "${TMP_DIR}/make-help.txt" "make longhorn-ui Port-forward the Longhorn UI to localhost:8081"

make -n restart-node NODE=talos-ts-worker1 > "${TMP_DIR}/make-restart-node.txt"
assert_contains "${TMP_DIR}/make-restart-node.txt" "NODE=\"talos-ts-worker1\" scripts/restart-node.sh"

make -n bootstrap-from-scratch > "${TMP_DIR}/make-bootstrap-from-scratch.txt"
assert_contains "${TMP_DIR}/make-bootstrap-from-scratch.txt" "scripts/bootstrap-from-scratch.sh"

echo "script behavior tests passed"
