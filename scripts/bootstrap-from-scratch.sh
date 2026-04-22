#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env

"${ROOT_DIR}/scripts/stop-vms.sh"
rm -rf "$(state_path disks)" "$(state_path node-name-suffix)"
unset CONTROL_PLANE_ENDPOINT CONTROL_PLANE_NODE_NAMES WORKER_NODE_NAMES NODE_NAMES NODE_NAME_SUFFIX_RESOLVED
"${ROOT_DIR}/scripts/generate-configs.sh"
"${ROOT_DIR}/scripts/start-vms.sh"
"${ROOT_DIR}/scripts/wait-talos-apis.sh"
"${ROOT_DIR}/scripts/apply-configs.sh"
"${ROOT_DIR}/scripts/wait-talos-apis.sh"
"${ROOT_DIR}/scripts/bootstrap.sh"
