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
for attempt in {1..120}; do
  if talosctl --endpoints "127.0.0.1:${FIRST_PORT}" --nodes 127.0.0.1 version >/dev/null 2>&1; then
    break
  fi
  if [[ "${attempt}" == 120 ]]; then
    echo "Talos API did not become ready on localhost:${FIRST_PORT}" >&2
    exit 1
  fi
  sleep 2
done

log "Bootstrapping etcd on ${FIRST_NODE}"
talosctl --endpoints "127.0.0.1:${FIRST_PORT}" --nodes 127.0.0.1 bootstrap

log "Fetching kubeconfig"
talosctl --endpoints "127.0.0.1:${FIRST_PORT}" --nodes 127.0.0.1 kubeconfig "$(state_path kubeconfig/config)" --merge=false --force

log "Bootstrap requested. Use scripts/validate.sh once all nodes have joined Tailscale."
