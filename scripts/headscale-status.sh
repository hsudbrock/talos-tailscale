#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env

require_cmd tailscale

echo "== Host tailscale status =="
tailscale status

if ! headscale_local_vm_enabled; then
  echo
  echo "Local Headscale VM status skipped for HEADSCALE_BOOTSTRAP_MODE=${HEADSCALE_BOOTSTRAP_MODE}"
  exit 0
fi

HEADSCALE_PACKER_KEY="$(state_path headscale/packer/id_ed25519)"
if [[ ! -f "${HEADSCALE_PACKER_KEY}" ]]; then
  echo
  echo "Local Headscale VM status skipped; missing ${HEADSCALE_PACKER_KEY}" >&2
  exit 0
fi

require_cmd ssh

headscale_ssh() {
  ssh \
    -i "${HEADSCALE_PACKER_KEY}" \
    -o BatchMode=yes \
    -o LogLevel=ERROR \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=5 \
    -p "${HEADSCALE_HOST_SSH_PORT}" \
    "${HEADSCALE_PACKER_SSH_USERNAME}@127.0.0.1" \
    "$@"
}

echo
echo "== Headscale service status =="
headscale_ssh "sudo systemctl status headscale --no-pager --lines=10"

echo
echo "== Headscale nodes =="
headscale_ssh "sudo headscale nodes list"
