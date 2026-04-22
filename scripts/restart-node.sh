#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env

NODE="${NODE:-}"
if [[ -z "${NODE}" ]]; then
  echo "missing NODE; use NODE=<node-name>" >&2
  exit 1
fi

stop_vm "${NODE}"
start_vm "${NODE}"
