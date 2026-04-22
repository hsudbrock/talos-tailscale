#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env

for node in "${NODES[@]}"; do
  stop_vm "${node}"
done
