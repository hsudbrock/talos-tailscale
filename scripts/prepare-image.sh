#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env
ensure_state_dir
require_cmd curl
require_cmd sha256sum

SCHEMATIC_FILE="$(state_path schematic.yaml)"
SCHEMATIC_ID_FILE="$(state_path schematic.id)"
ISO_FILE="$(state_path "assets/talos-${TALOS_VERSION}-tailscale-metal-amd64.iso")"

cat > "${SCHEMATIC_FILE}" <<'YAML'
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/tailscale
      - siderolabs/iscsi-tools
      - siderolabs/util-linux-tools
YAML

log "Submitting Talos Image Factory schematic with Tailscale and Longhorn extensions"
SCHEMATIC_ID="$(
  curl -fsSL \
    -X POST \
    --data-binary @"${SCHEMATIC_FILE}" \
    https://factory.talos.dev/schematics |
    sed -n 's/.*"id":"\([^"]*\)".*/\1/p'
)"

if [[ -z "${SCHEMATIC_ID}" ]]; then
  echo "failed to parse Talos Image Factory schematic id" >&2
  exit 1
fi

printf '%s\n' "${SCHEMATIC_ID}" > "${SCHEMATIC_ID_FILE}"

ISO_URL="https://factory.talos.dev/image/${SCHEMATIC_ID}/${TALOS_VERSION}/metal-amd64.iso"
log "Downloading ${ISO_URL}"
curl -fL "${ISO_URL}" -o "${ISO_FILE}"

log "Image ready: ${ISO_FILE}"
log "Schematic id: ${SCHEMATIC_ID}"
