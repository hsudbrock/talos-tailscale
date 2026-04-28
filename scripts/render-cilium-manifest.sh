#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env
ensure_state_dir
require_cmd helm

OUT_DIR="$(state_path cilium)"
OUT_FILE="${OUT_DIR}/cilium-bootstrap.yaml"
VALUES_FILE="${OUT_DIR}/values.yaml"

mkdir -p "${OUT_DIR}"

cat > "${VALUES_FILE}" <<YAML
ipam:
  mode: kubernetes
kubeProxyReplacement: false
routingMode: tunnel
tunnelProtocol: vxlan
cgroup:
  autoMount:
    enabled: false
  hostRoot: /sys/fs/cgroup
securityContext:
  capabilities:
    ciliumAgent:
      - CHOWN
      - KILL
      - NET_ADMIN
      - NET_RAW
      - IPC_LOCK
      - SYS_ADMIN
      - SYS_RESOURCE
      - DAC_OVERRIDE
      - FOWNER
      - SETGID
      - SETUID
    cleanCiliumState:
      - NET_ADMIN
      - SYS_ADMIN
      - SYS_RESOURCE
hubble:
  enabled: true
  tls:
    auto:
      method: cronJob
  relay:
    enabled: true
  ui:
    enabled: true
YAML

helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1 || true
helm repo update cilium >/dev/null

{
  cat <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: kube-system
YAML
  helm template \
    cilium \
    cilium/cilium \
    --version "${CILIUM_VERSION}" \
    --namespace kube-system \
    --values "${VALUES_FILE}"
} > "${OUT_FILE}"

log "Rendered Cilium bootstrap manifest: ${OUT_FILE}"
