#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env

: "${WAIT_TALOS_TIMEOUT_SECONDS:=240}"
: "${WAIT_TALOS_INTERVAL_SECONDS:=2}"
: "${WAIT_TALOS_PROBE:=port}"

if (( WAIT_TALOS_TIMEOUT_SECONDS < WAIT_TALOS_INTERVAL_SECONDS )); then
  echo "WAIT_TALOS_TIMEOUT_SECONDS must be >= WAIT_TALOS_INTERVAL_SECONDS" >&2
  exit 1
fi

wait_for_local_port() {
  local host="$1"
  local port="$2"

  timeout 1 bash -c "exec 3<>/dev/tcp/${host}/${port}" >/dev/null 2>&1
}

wait_for_talos_api() {
  local api_port="$1"

  case "${WAIT_TALOS_PROBE}" in
    port)
      wait_for_local_port 127.0.0.1 "${api_port}"
      ;;
    version)
      require_cmd talosctl
      talosctl --insecure --endpoints "127.0.0.1:${api_port}" --nodes 127.0.0.1 version >/dev/null 2>&1
      ;;
    *)
      echo "unknown WAIT_TALOS_PROBE: ${WAIT_TALOS_PROBE}" >&2
      exit 1
      ;;
  esac
}

for node in "${NODES[@]}"; do
  idx="$(node_index "${node}")"
  api_port="$(api_port_for_index "${idx}")"
  attempts="$((WAIT_TALOS_TIMEOUT_SECONDS / WAIT_TALOS_INTERVAL_SECONDS))"

  log "Waiting for Talos API on ${node} via localhost:${api_port}"
  for attempt in $(seq 1 "${attempts}"); do
    if wait_for_talos_api "${api_port}"; then
      break
    fi
    if [[ "${attempt}" == "${attempts}" ]]; then
      echo "Talos API did not become ready on localhost:${api_port} for ${node}" >&2
      exit 1
    fi
    sleep "${WAIT_TALOS_INTERVAL_SECONDS}"
  done
done
