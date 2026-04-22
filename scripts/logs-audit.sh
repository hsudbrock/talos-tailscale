#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env
require_cmd talosctl
require_cmd mktemp

TALOSCONFIG="$(state_path talos/generated/talosconfig)"
TAIL_LINES="${LOG_AUDIT_TAIL_LINES:-400}"
RECENT_LINES="${LOG_AUDIT_RECENT_LINES:-80}"

if [[ ! -f "${TALOSCONFIG}" ]]; then
  echo "missing ${TALOSCONFIG}; run scripts/generate-configs.sh first" >&2
  exit 1
fi

if (( TAIL_LINES < RECENT_LINES )); then
  echo "LOG_AUDIT_TAIL_LINES must be >= LOG_AUDIT_RECENT_LINES" >&2
  exit 1
fi

export TALOSCONFIG

summarize_pattern() {
  local node="$1"
  local service="$2"
  local label="$3"
  local pattern="$4"
  local log_file="$5"
  local total_count recent_count state

  total_count="$(rg -c -- "${pattern}" "${log_file}" || true)"
  total_count="${total_count:-0}"
  if [[ "${total_count}" == "0" ]]; then
    return 0
  fi

  recent_count="$(tail -n "${RECENT_LINES}" "${log_file}" | rg -c -- "${pattern}" || true)"
  recent_count="${recent_count:-0}"
  if [[ "${recent_count}" == "0" ]]; then
    state="historical"
  else
    state="recurring"
  fi

  printf '%-24s %-14s %-16s %-10s total=%s recent=%s\n' "${node}" "${service}" "${label}" "${state}" "${total_count}" "${recent_count}"
}

audit_service() {
  local node="$1"
  local service="$2"
  local log_file

  log_file="$(mktemp)"
  talosctl --endpoints "${node}" --nodes "${node}" logs "${service}" --tail "${TAIL_LINES}" > "${log_file}"

  case "${service}" in
    machined)
      summarize_pattern "${node}" "${service}" "endpoint-dns" "StaticEndpointController|lookup .*127\\.0\\.0\\.53|no such host" "${log_file}"
      ;;
    ext-tailscale)
      summarize_pattern "${node}" "${service}" "dns-write" "dns-set-os-config-failed|resolv\\.pre-tailscale-backup|read-only file system" "${log_file}"
      ;;
  esac

  rm -f "${log_file}"
}

printf '%-24s %-14s %-16s %-10s %s\n' "NODE" "SERVICE" "PATTERN" "STATE" "COUNTS"

for node in "${NODES[@]}"; do
  audit_service "${node}" "machined"
  audit_service "${node}" "ext-tailscale"
done
