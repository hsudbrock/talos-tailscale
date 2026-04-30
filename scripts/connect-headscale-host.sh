#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env

if ! headscale_support_enabled; then
  echo "HEADSCALE_BOOTSTRAP_MODE must be local-vm or external to connect the host to Headscale" >&2
  exit 1
fi

require_cmd tailscale

if [[ "${HEADSCALE_BOOTSTRAP_MODE}" == "external" && -z "${HEADSCALE_HOST_AUTH_KEY}" ]]; then
  echo "missing HEADSCALE_HOST_AUTH_KEY for HEADSCALE_BOOTSTRAP_MODE=external" >&2
  exit 1
fi

HOST_AUTH_KEY="$(
  HEADSCALE_AUTH_KEY="${HEADSCALE_HOST_AUTH_KEY}" \
  HEADSCALE_AUTH_KEY_FILE="${HEADSCALE_HOST_AUTH_KEY_FILE}" \
  HEADSCALE_TALOS_USER="${HEADSCALE_HOST_USER}" \
  HEADSCALE_TALOS_TAG="${HEADSCALE_HOST_TAG}" \
  HEADSCALE_TALOS_KEY_EXPIRATION="${HEADSCALE_HOST_KEY_EXPIRATION}" \
    "${ROOT_DIR}/scripts/ensure-headscale-auth-key.sh"
)"

tailscale_cmd=(tailscale up --login-server "${HEADSCALE_HOST_CONNECT_URL}" --auth-key "${HOST_AUTH_KEY}" "--accept-dns=${HEADSCALE_HOST_ACCEPT_DNS}" --reset)

if [[ "${EUID}" == "0" ]]; then
  "${tailscale_cmd[@]}"
elif command -v sudo >/dev/null 2>&1; then
  sudo "${tailscale_cmd[@]}"
else
  "${tailscale_cmd[@]}"
fi

log "Host connected to Headscale via ${HEADSCALE_HOST_CONNECT_URL}"
