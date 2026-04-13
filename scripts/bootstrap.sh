#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env
require_cmd talosctl

TALOSCONFIG="$(state_path talos/generated/talosconfig)"
FIRST_NODE="${NODES[0]}"
FIRST_PORT="$(api_port_for_index 1)"

if [[ ! -f "${TALOSCONFIG}" ]]; then
  echo "missing ${TALOSCONFIG}; run scripts/generate-configs.sh first" >&2
  exit 1
fi

export TALOSCONFIG

log "Waiting for Talos API on first node localhost:${FIRST_PORT}"
talosctl --nodes "127.0.0.1:${FIRST_PORT}" health --wait-timeout 20m --server=false

log "Bootstrapping etcd on ${FIRST_NODE}"
talosctl --nodes "127.0.0.1:${FIRST_PORT}" bootstrap

log "Fetching kubeconfig"
talosctl --nodes "127.0.0.1:${FIRST_PORT}" kubeconfig "$(state_path kubeconfig/config)" --merge=false --force

log "Bootstrap requested. Use scripts/validate.sh once all nodes have joined Tailscale."
