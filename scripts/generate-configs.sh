#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env
ensure_state_dir
require_cmd talosctl
require_env TS_AUTHKEY

SCHEMATIC_ID_FILE="$(state_path schematic.id)"
if [[ ! -f "${SCHEMATIC_ID_FILE}" ]]; then
  echo "missing $(realpath "${SCHEMATIC_ID_FILE}"); run scripts/prepare-image.sh first" >&2
  exit 1
fi

SCHEMATIC_ID="$(<"${SCHEMATIC_ID_FILE}")"
INSTALL_IMAGE="factory.talos.dev/installer/${SCHEMATIC_ID}:${TALOS_VERSION}"
PATCH_COMMON="$(state_path patches/common.yaml)"
BASE_DIR="$(state_path talos/base)"
OUT_DIR="$(state_path talos/generated)"

rm -rf "${BASE_DIR}" "${OUT_DIR}" "$(state_path patches/nodes)"
mkdir -p "${BASE_DIR}" "${OUT_DIR}" "$(state_path patches/nodes)"

SAN_ARGS=()
for node in "${NODES[@]}"; do
  SAN_ARGS+=(--additional-sans "${node}")
done
SAN_ARGS+=(--additional-sans "localhost" --additional-sans "127.0.0.1")

cat > "${PATCH_COMMON}" <<YAML
machine:
  kubelet:
    nodeIP:
      validSubnets:
        - ${TAILSCALE_CIDR}
cluster:
  etcd:
    advertisedSubnets:
      - ${TAILSCALE_CIDR}
  network:
    cni:
      name: flannel
      flannel:
        extraArgs:
          - --iface=tailscale0
YAML

talosctl gen config \
  "${CLUSTER_NAME}" \
  "${CONTROL_PLANE_ENDPOINT}" \
  --output "${BASE_DIR}" \
  --output-types controlplane,talosconfig \
  --install-disk "${INSTALL_DISK}" \
  --install-image "${INSTALL_IMAGE}" \
  --kubernetes-version "${KUBERNETES_VERSION}" \
  --talos-version "${TALOS_VERSION}" \
  --config-patch-control-plane @"${PATCH_COMMON}" \
  "${SAN_ARGS[@]}" \
  --force

for node in "${NODES[@]}"; do
  idx="$(node_index "${node}")"
  patch_file="$(state_path "patches/nodes/${node}.yaml")"
  cat > "${patch_file}" <<YAML
machine:
  network:
    hostname: ${node}
---
apiVersion: v1alpha1
kind: ExtensionServiceConfig
name: tailscale
environment:
  - TS_AUTHKEY=${TS_AUTHKEY}
  - TS_HOSTNAME=${node}
  - TS_ACCEPT_DNS=true
  - TS_STATE_DIR=/var/lib/tailscale
  - TS_EXTRA_ARGS=--reset
YAML

  talosctl machineconfig patch \
    "${BASE_DIR}/controlplane.yaml" \
    --patch @"${patch_file}" \
    --output "${OUT_DIR}/${node}.yaml"

  log "Generated config for ${node}; first-boot Talos API: 127.0.0.1:$(api_port_for_index "${idx}")"
done

cp "${BASE_DIR}/talosconfig" "${OUT_DIR}/talosconfig"
log "Generated talosconfig: ${OUT_DIR}/talosconfig"
