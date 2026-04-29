#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env

headscale_support_enabled || exit 0

if (( HEADSCALE_READY_TIMEOUT_SECONDS < HEADSCALE_READY_INTERVAL_SECONDS )); then
  echo "HEADSCALE_READY_TIMEOUT_SECONDS must be >= HEADSCALE_READY_INTERVAL_SECONDS" >&2
  exit 1
fi

: "${HEADSCALE_READY_PROBE:=port}"

if [[ "${HEADSCALE_READY_PROBE}" == "pidfile" ]]; then
  headscale_local_vm_enabled || {
    echo "HEADSCALE_READY_PROBE=pidfile requires HEADSCALE_BOOTSTRAP_MODE=local-vm" >&2
    exit 1
  }
  pidfile="$(state_path "${HEADSCALE_VM_NAME}.pid")"
  [[ -f "${pidfile}" ]] || {
    echo "Headscale pidfile not found: ${pidfile}" >&2
    exit 1
  }
  exit 0
fi

probe_host=""
probe_port=""

if [[ "${HEADSCALE_BOOTSTRAP_MODE}" == "local-vm" ]]; then
  probe_host="127.0.0.1"
  probe_port="${HEADSCALE_HOST_HTTP_PORT}"
elif [[ -n "${HEADSCALE_URL}" ]]; then
  parsed="${HEADSCALE_URL#*://}"
  parsed="${parsed%%/*}"
  probe_host="${parsed%%:*}"
  probe_port="${parsed##*:}"
  if [[ "${probe_host}" == "${probe_port}" ]]; then
    case "${HEADSCALE_URL}" in
      https://*) probe_port="443" ;;
      *) probe_port="80" ;;
    esac
  fi
fi

if [[ -z "${probe_host}" || -z "${probe_port}" ]]; then
  echo "could not determine Headscale readiness probe target; set HEADSCALE_URL or use HEADSCALE_BOOTSTRAP_MODE=local-vm" >&2
  exit 1
fi

wait_for_local_port() {
  local host="$1"
  local port="$2"

  timeout 1 bash -c "exec 3<>/dev/tcp/${host}/${port}" >/dev/null 2>&1
}

attempts="$((HEADSCALE_READY_TIMEOUT_SECONDS / HEADSCALE_READY_INTERVAL_SECONDS))"
log "Waiting for Headscale via ${probe_host}:${probe_port}"
for attempt in $(seq 1 "${attempts}"); do
  if wait_for_local_port "${probe_host}" "${probe_port}"; then
    exit 0
  fi
  if [[ "${attempt}" == "${attempts}" ]]; then
    echo "Headscale did not become ready on ${probe_host}:${probe_port}" >&2
    exit 1
  fi
  sleep "${HEADSCALE_READY_INTERVAL_SECONDS}"
done
