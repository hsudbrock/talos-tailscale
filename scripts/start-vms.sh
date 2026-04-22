#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env

for node in "${NODES[@]}"; do
  start_vm "${node}"
done

log "VMs are isolated by QEMU user-mode networking; no shared bridge is created."
