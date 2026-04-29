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
PATCH_CONTROL_PLANE="$(state_path patches/control-plane.yaml)"
PATCH_WORKER="$(state_path patches/worker.yaml)"
BASE_DIR="$(state_path talos/base)"
OUT_DIR="$(state_path talos/generated)"
LONGHORN_VOLUME_NAME="${LONGHORN_VOLUME_NAME:-longhorn}"
LONGHORN_DATA_PATH="/var/mnt/${LONGHORN_VOLUME_NAME}"
LONGHORN_DISK_SELECTOR="${LONGHORN_DISK_SELECTOR:-disk.dev_path == \"/dev/vdb\"}"
LONGHORN_VOLUME_MAX_SIZE="${LONGHORN_VOLUME_MAX_SIZE:-16GiB}"

if [[ "${CLUSTER_CNI}" == "cilium" ]]; then
  "${ROOT_DIR}/scripts/render-cilium-manifest.sh"
fi

rm -rf "${BASE_DIR}" "${OUT_DIR}" "$(state_path patches/nodes)"
mkdir -p "${BASE_DIR}" "${OUT_DIR}" "$(state_path patches/nodes)"

SAN_ARGS=()
for node in "${NODES[@]}"; do
  SAN_ARGS+=(--additional-sans "${node}")
done
SAN_ARGS+=(--additional-sans "localhost" --additional-sans "127.0.0.1")

if [[ "${CLUSTER_CNI}" == "cilium" ]]; then
  cat > "${PATCH_COMMON}" <<YAML
machine:
  features:
    kubePrism:
      enabled: true
      port: 7445
  kubelet:
    nodeIP:
      validSubnets:
        - ${TAILSCALE_CIDR}
cluster:
  proxy:
    disabled: true
  network:
    cni:
      name: none
YAML
else
  cat > "${PATCH_COMMON}" <<YAML
machine:
  kubelet:
    nodeIP:
      validSubnets:
        - ${TAILSCALE_CIDR}
cluster:
  network:
    cni:
      name: flannel
      flannel:
        extraArgs:
          - --iface=tailscale0
YAML
fi

{
  printf -- '---\n'
  printf 'apiVersion: v1alpha1\n'
  printf 'kind: ResolverConfig\n'
  printf 'nameservers:\n'
  read -r -a resolver_addrs <<< "${TAILSCALE_DNS_RESOLVERS}"
  for resolver in "${resolver_addrs[@]}"; do
    printf '  - address: %s\n' "${resolver}"
  done
  if [[ -n "${TAILSCALE_SEARCH_DOMAIN}" ]]; then
    printf 'searchDomains:\n'
    printf '  domains:\n'
    printf '    - %s\n' "${TAILSCALE_SEARCH_DOMAIN}"
  fi
} >> "${PATCH_COMMON}"

cat > "${PATCH_CONTROL_PLANE}" <<YAML
cluster:
  etcd:
    advertisedSubnets:
      - ${TAILSCALE_CIDR}
YAML

if [[ "${CLUSTER_CNI}" == "cilium" ]]; then
  {
    printf '  inlineManifests:\n'
    printf '    - name: cilium\n'
    printf '      contents: |\n'
    sed 's/^/        /' "$(state_path cilium/cilium-bootstrap.yaml)"
  } >> "${PATCH_CONTROL_PLANE}"
fi

cat > "${PATCH_WORKER}" <<YAML
machine:
  kubelet:
    extraMounts:
      - destination: ${LONGHORN_DATA_PATH}
        type: bind
        source: ${LONGHORN_DATA_PATH}
        options:
          - bind
          - rshared
          - rw
YAML

talosctl gen config \
  "${CLUSTER_NAME}" \
  "${CONTROL_PLANE_ENDPOINT}" \
  --output "${BASE_DIR}" \
  --output-types controlplane,worker,talosconfig \
  --install-disk "${INSTALL_DISK}" \
  --install-image "${INSTALL_IMAGE}" \
  --kubernetes-version "${KUBERNETES_VERSION}" \
  --talos-version "${TALOS_VERSION}" \
  --config-patch-control-plane @"${PATCH_COMMON}" \
  --config-patch-control-plane @"${PATCH_CONTROL_PLANE}" \
  --config-patch-worker @"${PATCH_COMMON}" \
  --config-patch-worker @"${PATCH_WORKER}" \
  "${SAN_ARGS[@]}" \
  --force

set_hostname_config() {
  local config="$1"
  local node="$2"
  local tmp_config

  if ! grep -Eq '^kind:[[:space:]]*HostnameConfig[[:space:]]*$' "${config}"; then
    echo "${config} does not contain HostnameConfig; Talos ${TALOS_VERSION} is below the supported minimum" >&2
    exit 1
  fi

  tmp_config="$(mktemp)"
  awk -v node="${node}" '
    /^---[[:space:]]*$/ {
      if (in_hostname_config && !wrote_hostname) {
        print "hostname: " node
      }
      in_hostname_config = 0
      wrote_hostname = 0
      print
      next
    }
    /^kind:[[:space:]]*HostnameConfig[[:space:]]*$/ {
      in_hostname_config = 1
      print
      next
    }
    in_hostname_config && /^auto:[[:space:]]*/ {
      if (!wrote_hostname) {
        print "hostname: " node
        wrote_hostname = 1
      }
      next
    }
    in_hostname_config && /^hostname:[[:space:]]*/ {
      if (!wrote_hostname) {
        print "hostname: " node
        wrote_hostname = 1
      }
      next
    }
    {
      print
    }
    END {
      if (in_hostname_config && !wrote_hostname) {
        print "hostname: " node
      }
    }
  ' "${config}" > "${tmp_config}"
  mv "${tmp_config}" "${config}"
}

append_longhorn_user_volume_config() {
  local config="$1"

  cat >> "${config}" <<YAML
---
apiVersion: v1alpha1
kind: UserVolumeConfig
name: ${LONGHORN_VOLUME_NAME}
provisioning:
  diskSelector:
    match: ${LONGHORN_DISK_SELECTOR}
  maxSize: ${LONGHORN_VOLUME_MAX_SIZE}
YAML
}

generate_node_config() {
  local node="$1"
  local base_config="$2"
  local idx patch_file

  idx="$(node_index "${node}")"
  patch_file="$(state_path "patches/nodes/${node}.yaml")"
  cat > "${patch_file}" <<YAML
apiVersion: v1alpha1
kind: ExtensionServiceConfig
name: tailscale
environment:
  - TS_AUTHKEY=${TS_AUTHKEY}
  - TS_HOSTNAME=${node}
  - TS_ACCEPT_DNS=${TAILSCALE_ACCEPT_DNS}
  - TS_STATE_DIR=/var/lib/tailscale
  - TS_EXTRA_ARGS=--reset
YAML

  talosctl machineconfig patch \
    "${base_config}" \
    --patch @"${patch_file}" \
    --output "${OUT_DIR}/${node}.yaml"

  set_hostname_config "${OUT_DIR}/${node}.yaml" "${node}"
  if [[ "${base_config}" == "${BASE_DIR}/worker.yaml" ]]; then
    append_longhorn_user_volume_config "${OUT_DIR}/${node}.yaml"
  fi
  log "Generated config for ${node}; first-boot Talos API: 127.0.0.1:$(api_port_for_index "${idx}")"
}

for node in "${CONTROL_PLANE_NODES[@]}"; do
  generate_node_config "${node}" "${BASE_DIR}/controlplane.yaml"
done

for node in "${WORKER_NODES[@]}"; do
  generate_node_config "${node}" "${BASE_DIR}/worker.yaml"
done

cp "${BASE_DIR}/talosconfig" "${OUT_DIR}/talosconfig"
log "Generated talosconfig: ${OUT_DIR}/talosconfig"
