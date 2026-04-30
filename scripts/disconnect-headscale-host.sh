#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env

require_cmd tailscale

disconnect_cmd=(tailscale logout)

if [[ "${EUID}" == "0" ]]; then
  "${disconnect_cmd[@]}"
elif command -v sudo >/dev/null 2>&1; then
  sudo "${disconnect_cmd[@]}"
else
  "${disconnect_cmd[@]}"
fi

log "Host disconnected from Headscale"
