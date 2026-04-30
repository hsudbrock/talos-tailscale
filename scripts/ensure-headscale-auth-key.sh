#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env
ensure_state_dir

if ! headscale_support_enabled; then
  echo "HEADSCALE_BOOTSTRAP_MODE must be local-vm or external to resolve a Headscale auth key" >&2
  exit 1
fi

AUTH_KEY_VALUE="${HEADSCALE_AUTH_KEY}"
AUTH_KEY_FILE="${HEADSCALE_AUTH_KEY_FILE}"
AUTH_KEY_USER="${HEADSCALE_TALOS_USER}"
AUTH_KEY_TAG="${HEADSCALE_TALOS_TAG}"
AUTH_KEY_EXPIRATION="${HEADSCALE_TALOS_KEY_EXPIRATION}"

if [[ -n "${AUTH_KEY_VALUE}" ]]; then
  printf '%s\n' "${AUTH_KEY_VALUE}"
  exit 0
fi

if ! headscale_local_vm_enabled; then
  echo "missing HEADSCALE_AUTH_KEY; set it in the environment for HEADSCALE_BOOTSTRAP_MODE=${HEADSCALE_BOOTSTRAP_MODE}" >&2
  exit 1
fi

require_cmd ssh
require_cmd python3

HEADSCALE_PACKER_KEY="$(state_path headscale/packer/id_ed25519)"
HEADSCALE_SSH_HOST="127.0.0.1"
HEADSCALE_SSH_PORT="${HEADSCALE_HOST_SSH_PORT}"
HEADSCALE_SSH_USER="${HEADSCALE_PACKER_SSH_USERNAME}"

if [[ ! -f "${HEADSCALE_PACKER_KEY}" ]]; then
  echo "missing ${HEADSCALE_PACKER_KEY}; build the Headscale image with make headscale-image first" >&2
  exit 1
fi

headscale_ssh() {
  ssh \
    -i "${HEADSCALE_PACKER_KEY}" \
    -o BatchMode=yes \
    -o LogLevel=ERROR \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=5 \
    -p "${HEADSCALE_SSH_PORT}" \
    "${HEADSCALE_SSH_USER}@${HEADSCALE_SSH_HOST}" \
    "$@"
}

wait_for_headscale_ssh() {
  local attempts attempt

  attempts="$((HEADSCALE_READY_TIMEOUT_SECONDS / HEADSCALE_READY_INTERVAL_SECONDS))"
  log "Waiting for Headscale SSH via ${HEADSCALE_SSH_HOST}:${HEADSCALE_SSH_PORT}" >&2
  for attempt in $(seq 1 "${attempts}"); do
    if headscale_ssh "true" >/dev/null 2>&1; then
      return 0
    fi
    if [[ "${attempt}" == "${attempts}" ]]; then
      echo "Headscale SSH did not become ready on ${HEADSCALE_SSH_HOST}:${HEADSCALE_SSH_PORT}" >&2
      return 1
    fi
    sleep "${HEADSCALE_READY_INTERVAL_SECONDS}"
  done
}

wait_for_headscale_cli() {
  local attempts attempt

  attempts="$((HEADSCALE_READY_TIMEOUT_SECONDS / HEADSCALE_READY_INTERVAL_SECONDS))"
  log "Waiting for Headscale service readiness inside the VM" >&2
  for attempt in $(seq 1 "${attempts}"); do
    if headscale_ssh "sudo systemctl is-active --quiet headscale && sudo headscale nodes list >/dev/null" >/dev/null 2>&1; then
      return 0
    fi
    if [[ "${attempt}" == "${attempts}" ]]; then
      echo "Headscale service did not become CLI-ready inside the VM" >&2
      return 1
    fi
    sleep "${HEADSCALE_READY_INTERVAL_SECONDS}"
  done
}

ensure_auth_user() {
  local quoted_user

  printf -v quoted_user '%q' "${AUTH_KEY_USER}"
  headscale_ssh "sudo headscale users create ${quoted_user} --force >/dev/null 2>&1 || true" >/dev/null

  AUTH_KEY_USER_ID="$(
    headscale_ssh "sudo headscale users list -o json" \
      | python3 -c '
import json
import sys

target = sys.argv[1]
for user in json.load(sys.stdin):
    if user.get("name") == target:
        print(user["id"])
        break
' "${AUTH_KEY_USER}"
  )"
  AUTH_KEY_USER_ID="${AUTH_KEY_USER_ID//$'\r'/}"

  if [[ -z "${AUTH_KEY_USER_ID}" ]]; then
    echo "failed to resolve Headscale user id for ${AUTH_KEY_USER}" >&2
    exit 1
  fi
}

mkdir -p "$(dirname "${AUTH_KEY_FILE}")"

{ start_headscale_vm; } >&2
"${ROOT_DIR}/scripts/wait-headscale.sh" >&2
wait_for_headscale_ssh
wait_for_headscale_cli

log "Ensuring Headscale enrollment user ${AUTH_KEY_USER} exists" >&2
ensure_auth_user

log "Creating reusable Headscale auth key" >&2
create_key_cmd="sudo headscale preauthkeys create --user ${AUTH_KEY_USER_ID} --reusable --expiration ${AUTH_KEY_EXPIRATION}"
if [[ -n "${AUTH_KEY_TAG}" ]]; then
  create_key_cmd="${create_key_cmd} --tags ${AUTH_KEY_TAG}"
fi

AUTH_KEY_VALUE="$(
  headscale_ssh \
    "${create_key_cmd}" \
    | awk 'NF { line = $0 } END { print line }'
)"
AUTH_KEY_VALUE="${AUTH_KEY_VALUE//$'\r'/}"

if [[ -z "${AUTH_KEY_VALUE}" ]]; then
  echo "failed to capture Headscale auth key" >&2
  exit 1
fi

printf '%s\n' "${AUTH_KEY_VALUE}" > "${AUTH_KEY_FILE}"
chmod 600 "${AUTH_KEY_FILE}"
printf '%s\n' "${AUTH_KEY_VALUE}"
