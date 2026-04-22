#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env
require_cmd talosctl

WAIT_SCRIPT="${ROOT_DIR}/scripts/wait-talos-apis.sh"

if [[ ! -x "${WAIT_SCRIPT}" ]]; then
  echo "missing ${WAIT_SCRIPT}" >&2
  exit 1
fi

"${WAIT_SCRIPT}"

for node in "${NODES[@]}"; do
  idx="$(node_index "${node}")"
  config="$(state_path "talos/generated/${node}.yaml")"
  api_port="$(api_port_for_index "${idx}")"
  if [[ ! -f "${config}" ]]; then
    echo "missing ${config}; run scripts/generate-configs.sh first" >&2
    exit 1
  fi

  log "Applying config for ${node} via localhost:${api_port}"
  talosctl apply-config \
    --insecure \
    --nodes "127.0.0.1:${api_port}" \
    --file "${config}"
done
