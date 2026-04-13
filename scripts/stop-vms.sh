#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env

for node in "${NODES[@]}"; do
  pidfile="$(state_path "${node}.pid")"
  if [[ ! -f "${pidfile}" ]]; then
    log "${node} is not running"
    continue
  fi

  pid="$(<"${pidfile}")"
  if kill -0 "${pid}" 2>/dev/null; then
    log "Stopping ${node} pid ${pid}"
    kill "${pid}"
  fi
  rm -f "${pidfile}"
done
