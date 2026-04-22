#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env
require_cmd talosctl

for node in "${NODES[@]}"; do
  idx="$(node_index "${node}")"
  api_port="$(api_port_for_index "${idx}")"

  log "Waiting for Talos API on ${node} via localhost:${api_port}"
  for attempt in {1..120}; do
    if talosctl --insecure --endpoints "127.0.0.1:${api_port}" --nodes 127.0.0.1 version >/dev/null 2>&1; then
      break
    fi
    if [[ "${attempt}" == 120 ]]; then
      echo "Talos API did not become ready on localhost:${api_port} for ${node}" >&2
      exit 1
    fi
    sleep 2
  done
done
