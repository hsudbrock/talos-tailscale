#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${ROOT_DIR}/scripts/generate-configs.sh"
"${ROOT_DIR}/scripts/stop-vms.sh"
rm -rf "${ROOT_DIR}/.state/disks"
"${ROOT_DIR}/scripts/start-vms.sh"
"${ROOT_DIR}/scripts/wait-talos-apis.sh"
"${ROOT_DIR}/scripts/apply-configs.sh"
"${ROOT_DIR}/scripts/wait-talos-apis.sh"
"${ROOT_DIR}/scripts/bootstrap.sh"
