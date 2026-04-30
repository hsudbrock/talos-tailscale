#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env

require_cmd tailscale
require_cmd getent

if [[ "${#CONTROL_PLANE_NODES[@]}" -eq 0 ]]; then
  echo "no control-plane nodes configured" >&2
  exit 1
fi

fqdn="${CONTROL_PLANE_NODES[0]}.${HEADSCALE_BASE_DOMAIN}"

echo "== tailscale status =="
tailscale status

echo
echo "== Tailnet DNS lookup =="
echo "${fqdn}"
getent hosts "${fqdn}"

echo
echo "== Public DNS lookup =="
getent hosts example.com
