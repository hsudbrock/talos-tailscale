#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env
require_cmd talosctl

WAIT_SCRIPT="${ROOT_DIR}/scripts/wait-talos-apis.sh"
TALOSCONFIG="$(state_path talos/generated/talosconfig)"
AUTH_ENDPOINT_PORT="$(api_port_for_index 1)"

if [[ ! -x "${WAIT_SCRIPT}" ]]; then
  echo "missing ${WAIT_SCRIPT}" >&2
  exit 1
fi

"${WAIT_SCRIPT}"

apply_config_insecure() {
  local api_port="$1"
  local config="$2"

  talosctl apply-config \
    --insecure \
    --nodes "127.0.0.1:${api_port}" \
    --file "${config}"
}

apply_config_authenticated() {
  local node="$1"
  local config="$2"

  talosctl apply-config \
    --talosconfig "${TALOSCONFIG}" \
    --endpoints "127.0.0.1:${AUTH_ENDPOINT_PORT}" \
    --nodes "${node}" \
    --file "${config}"
}

apply_config_authenticated_with_retry() {
  local node="$1"
  local config="$2"
  local attempt authenticated_error_file authenticated_error

  for attempt in $(seq 1 30); do
    authenticated_error_file="$(mktemp)"
    if apply_config_authenticated "${node}" "${config}" 2>"${authenticated_error_file}"; then
      rm -f "${authenticated_error_file}"
      return 0
    fi

    authenticated_error="$(<"${authenticated_error_file}")"
    rm -f "${authenticated_error_file}"

    if [[ "${authenticated_error}" != *"authentication handshake failed"* &&
          "${authenticated_error}" != *"connection error"* &&
          "${authenticated_error}" != *"code = Unavailable"* &&
          "${authenticated_error}" != *"EOF"* ]]; then
      printf '%s\n' "${authenticated_error}" >&2
      return 1
    fi

    if [[ "${attempt}" == "30" ]]; then
      printf '%s\n' "${authenticated_error}" >&2
      return 1
    fi

    sleep 2
  done
}

for node in "${NODES[@]}"; do
  idx="$(node_index "${node}")"
  config="$(state_path "talos/generated/${node}.yaml")"
  api_port="$(api_port_for_index "${idx}")"
  insecure_error_file="$(mktemp)"
  if [[ ! -f "${config}" ]]; then
    echo "missing ${config}; run scripts/generate-configs.sh first" >&2
    exit 1
  fi

  log "Applying config for ${node} via localhost:${api_port}"
  if apply_config_insecure "${api_port}" "${config}" 2>"${insecure_error_file}"; then
    rm -f "${insecure_error_file}"
    continue
  fi

  insecure_error="$(<"${insecure_error_file}")"
  rm -f "${insecure_error_file}"
  printf '%s\n' "${insecure_error}" >&2

  if [[ "${insecure_error}" != *"tls: certificate required"* && "${insecure_error}" != *"authentication handshake failed"* ]]; then
    exit 1
  fi

  if [[ ! -f "${TALOSCONFIG}" ]]; then
    echo "missing ${TALOSCONFIG}; authenticated apply requires scripts/generate-configs.sh output" >&2
    exit 1
  fi

  log "Retrying authenticated apply for ${node} via control-plane localhost:${AUTH_ENDPOINT_PORT}"
  apply_config_authenticated_with_retry "${node}" "${config}"
done
