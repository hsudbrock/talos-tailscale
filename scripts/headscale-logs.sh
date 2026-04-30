#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env

log_file="$(state_path logs/headscale.log)"

echo "== Headscale serial log =="
if [[ -f "${log_file}" ]]; then
  tail -n 120 "${log_file}"
else
  echo "missing ${log_file}"
fi

if ! headscale_local_vm_enabled; then
  echo
  echo "Live Headscale journal skipped for HEADSCALE_BOOTSTRAP_MODE=${HEADSCALE_BOOTSTRAP_MODE}"
  exit 0
fi

HEADSCALE_PACKER_KEY="$(state_path headscale/packer/id_ed25519)"
if [[ ! -f "${HEADSCALE_PACKER_KEY}" ]]; then
  echo
  echo "Live Headscale journal skipped; missing ${HEADSCALE_PACKER_KEY}" >&2
  exit 0
fi

require_cmd ssh

echo
echo "== Headscale service journal =="
ssh \
  -i "${HEADSCALE_PACKER_KEY}" \
  -o BatchMode=yes \
  -o LogLevel=ERROR \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ConnectTimeout=5 \
  -p "${HEADSCALE_HOST_SSH_PORT}" \
  "${HEADSCALE_PACKER_SSH_USERNAME}@127.0.0.1" \
  "sudo journalctl -u headscale -n 120 --no-pager"
