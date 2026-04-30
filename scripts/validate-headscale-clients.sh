#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env

headscale_local_vm_enabled || {
  echo "HEADSCALE_BOOTSTRAP_MODE=local-vm is required for non-Talos Headscale client validation" >&2
  exit 1
}

require_cmd ssh
require_cmd tailscaled
require_cmd tailscale
require_cmd timeout
require_cmd pgrep
require_cmd python3

HEADSCALE_PACKER_KEY="$(state_path headscale/packer/id_ed25519)"
HEADSCALE_VALIDATE_DIR="$(state_path headscale/validate-clients)"
HEADSCALE_SSH_HOST="127.0.0.1"
HEADSCALE_SSH_PORT="${HEADSCALE_HOST_SSH_PORT}"
HEADSCALE_SSH_USER="${HEADSCALE_PACKER_SSH_USERNAME}"

if [[ ! -f "${HEADSCALE_PACKER_KEY}" ]]; then
  echo "missing ${HEADSCALE_PACKER_KEY}; build the Headscale image with make headscale-image first" >&2
  exit 1
fi

read -r -a HEADSCALE_VALIDATE_CLIENTS <<< "${HEADSCALE_VALIDATE_CLIENT_NAMES}"
if (( ${#HEADSCALE_VALIDATE_CLIENTS[@]} < 2 )); then
  echo "HEADSCALE_VALIDATE_CLIENT_NAMES must contain at least two client names" >&2
  exit 1
fi

client_socket_path() {
  local client_name="$1"
  echo "${HEADSCALE_VALIDATE_DIR}/${client_name}.sock"
}

client_pidfile_path() {
  local client_name="$1"
  echo "${HEADSCALE_VALIDATE_DIR}/${client_name}/tailscaled.pid"
}

client_log_path() {
  local client_name="$1"
  echo "${HEADSCALE_VALIDATE_DIR}/${client_name}/tailscaled.log"
}

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
  log "Waiting for Headscale SSH via ${HEADSCALE_SSH_HOST}:${HEADSCALE_SSH_PORT}"
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
  log "Waiting for Headscale service readiness inside the VM"
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

cleanup() {
  local client_name pidfile pid socket

  for client_name in "${HEADSCALE_VALIDATE_CLIENTS[@]}"; do
    stop_client_processes "${client_name}"
    socket="$(client_socket_path "${client_name}")"
    pidfile="$(client_pidfile_path "${client_name}")"

    if [[ -S "${socket}" || -e "${socket}" ]]; then
      tailscale --socket "${socket}" down >/dev/null 2>&1 || true
    fi

    if [[ -f "${pidfile}" ]]; then
      pid="$(<"${pidfile}")"
      if kill -0 "${pid}" 2>/dev/null; then
        kill "${pid}" >/dev/null 2>&1 || true
      fi
      rm -f "${pidfile}"
    fi

    rm -f "${socket}"
  done
}

trap cleanup EXIT

stop_client_processes() {
  local client_name="$1"
  local pattern pid

  pattern="${HEADSCALE_VALIDATE_DIR}/${client_name}"
  while IFS= read -r pid; do
    [[ -n "${pid}" ]] || continue
    if kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" >/dev/null 2>&1 || true
      wait_for_pid_exit "${pid}"
    fi
  done < <(pgrep -f "${pattern}" || true)
}

wait_for_pid_exit() {
  local pid="$1"
  local attempt

  for attempt in $(seq 1 10); do
    if ! kill -0 "${pid}" 2>/dev/null; then
      wait "${pid}" 2>/dev/null || true
      return 0
    fi
    sleep 1
  done

  kill -9 "${pid}" >/dev/null 2>&1 || true
  wait "${pid}" 2>/dev/null || true
}

start_userspace_client() {
  local client_name="$1"
  local client_dir socket pidfile log_file daemon_pid

  client_dir="${HEADSCALE_VALIDATE_DIR}/${client_name}"
  socket="$(client_socket_path "${client_name}")"
  pidfile="$(client_pidfile_path "${client_name}")"
  log_file="$(client_log_path "${client_name}")"

  stop_client_processes "${client_name}"
  rm -f "${socket}"
  rm -rf "${client_dir}"
  mkdir -p "${client_dir}"

  log "Starting userspace Tailscale client ${client_name}"
  tailscaled \
    --state="${client_dir}/state" \
    --socket="${socket}" \
    --tun=userspace-networking \
    --port=0 \
    --socks5-server=localhost:0 \
    --outbound-http-proxy-listen=localhost:0 \
    >"${log_file}" 2>&1 &
  daemon_pid=$!
  printf '%s\n' "${daemon_pid}" > "${pidfile}"

  for attempt in $(seq 1 30); do
    if tailscale --socket "${socket}" version >/dev/null 2>&1; then
      break
    fi
    if [[ "${attempt}" == "30" ]]; then
      echo "tailscaled for ${client_name} did not become ready; see ${log_file}" >&2
      exit 1
    fi
    sleep 1
  done

  if ! timeout 60 tailscale --socket "${socket}" up \
    --login-server "${HEADSCALE_VALIDATE_URL}" \
    --auth-key "${HEADSCALE_PREAUTH_KEY}" \
    --hostname "${client_name}" \
    --accept-dns=false \
    --reset >/dev/null; then
    echo "tailscale up failed for ${client_name}; see ${log_file}" >&2
    exit 1
  fi
}

client_ip_v4() {
  local client_name="$1"
  tailscale --socket "$(client_socket_path "${client_name}")" ip -4 | head -n 1
}

verify_node_registered() {
  local client_name="$1"

  if ! grep -Fq "${client_name}" <<< "${HEADSCALE_NODE_LIST}"; then
    echo "Headscale node list does not contain ${client_name}" >&2
    exit 1
  fi
}

ensure_validation_user() {
  local quoted_user

  printf -v quoted_user '%q' "${HEADSCALE_VALIDATE_USER}"
  headscale_ssh "sudo headscale users create ${quoted_user} --force >/dev/null 2>&1 || true" >/dev/null

  HEADSCALE_VALIDATE_USER_ID="$(
    headscale_ssh "sudo headscale users list -o json" \
      | python3 -c '
import json
import sys

target = sys.argv[1]
for user in json.load(sys.stdin):
    if user.get("name") == target:
        print(user["id"])
        break
' "${HEADSCALE_VALIDATE_USER}"
  )"
  HEADSCALE_VALIDATE_USER_ID="${HEADSCALE_VALIDATE_USER_ID//$'\r'/}"
  if [[ -z "${HEADSCALE_VALIDATE_USER_ID}" ]]; then
    echo "failed to resolve Headscale user id for ${HEADSCALE_VALIDATE_USER}" >&2
    exit 1
  fi
}

mkdir -p "${HEADSCALE_VALIDATE_DIR}"

log "Waiting for Headscale before client validation"
"${ROOT_DIR}/scripts/wait-headscale.sh"
wait_for_headscale_ssh
wait_for_headscale_cli

log "Ensuring validation user ${HEADSCALE_VALIDATE_USER} exists in Headscale"
ensure_validation_user

log "Creating reusable tagged preauth key on the local Headscale VM"
HEADSCALE_PREAUTH_KEY="$(
  headscale_ssh \
    "sudo headscale preauthkeys create --user ${HEADSCALE_VALIDATE_USER_ID} --reusable --expiration ${HEADSCALE_VALIDATE_KEY_EXPIRATION} --tags ${HEADSCALE_VALIDATE_TAG}" \
    | awk 'NF { line = $0 } END { print line }'
)"
HEADSCALE_PREAUTH_KEY="${HEADSCALE_PREAUTH_KEY//$'\r'/}"
if [[ -z "${HEADSCALE_PREAUTH_KEY}" ]]; then
  echo "failed to capture Headscale preauth key" >&2
  exit 1
fi

for client_name in "${HEADSCALE_VALIDATE_CLIENTS[@]}"; do
  start_userspace_client "${client_name}"
done

log "Checking that enrolled clients appear in Headscale node listings"
HEADSCALE_NODE_LIST="$(headscale_ssh "sudo headscale nodes list")"
for client_name in "${HEADSCALE_VALIDATE_CLIENTS[@]}"; do
  verify_node_registered "${client_name}"
done

source_client="${HEADSCALE_VALIDATE_CLIENTS[0]}"
target_client="${HEADSCALE_VALIDATE_CLIENTS[1]}"
target_ip="$(client_ip_v4 "${target_client}")"
if [[ -z "${target_ip}" ]]; then
  echo "could not determine Tailscale IPv4 for ${target_client}" >&2
  exit 1
fi

log "Checking tailnet connectivity from ${source_client} to ${target_client} (${target_ip})"
timeout 30 tailscale --socket "$(client_socket_path "${source_client}")" ping "${target_ip}" >/dev/null

log "Headscale client validation succeeded for: ${HEADSCALE_VALIDATE_CLIENTS[*]}"
