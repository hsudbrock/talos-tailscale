#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env
ensure_state_dir
require_cmd curl
require_cmd packer
require_cmd qemu-system-x86_64
require_cmd qemu-img
require_cmd ssh-keygen

HEADSCALE_STATE_DIR="$(state_path headscale)"
HEADSCALE_ASSET_DIR="$(state_path assets/headscale)"
HEADSCALE_PACKER_DIR="${HEADSCALE_STATE_DIR}/packer"
HEADSCALE_PACKER_OUTPUT_DIR="${HEADSCALE_PACKER_DIR}/output"
HEADSCALE_TEMPLATE="${ROOT_DIR}/config/headscale/config.yaml.tpl"
HEADSCALE_USER_DATA_TEMPLATE="${ROOT_DIR}/config/headscale/user-data.tpl"
HEADSCALE_META_DATA_TEMPLATE="${ROOT_DIR}/config/headscale/meta-data.tpl"
PACKER_TEMPLATE="${ROOT_DIR}/packer/headscale.pkr.hcl"

HEADSCALE_BASE_IMAGE="${HEADSCALE_BASE_IMAGE:-${HEADSCALE_ASSET_DIR}/debian-12-genericcloud-amd64.qcow2}"
HEADSCALE_DEB="${HEADSCALE_DEB:-${HEADSCALE_ASSET_DIR}/headscale_${HEADSCALE_VERSION}_linux_${HEADSCALE_ARCH}.deb}"
HEADSCALE_RENDERED_CONFIG="${HEADSCALE_PACKER_DIR}/config.yaml"
HEADSCALE_RENDERED_USER_DATA="${HEADSCALE_PACKER_DIR}/user-data"
HEADSCALE_RENDERED_META_DATA="${HEADSCALE_PACKER_DIR}/meta-data"
HEADSCALE_PACKER_SSH_KEY="${HEADSCALE_PACKER_DIR}/id_ed25519"
HEADSCALE_PACKER_SSH_PUBLIC_KEY="${HEADSCALE_PACKER_SSH_KEY}.pub"
HEADSCALE_IMAGE_NAME="$(basename "${HEADSCALE_IMAGE_OUTPUT}")"

mkdir -p "${HEADSCALE_STATE_DIR}" "${HEADSCALE_ASSET_DIR}" "${HEADSCALE_PACKER_DIR}"

for required in \
  "${HEADSCALE_TEMPLATE}" \
  "${HEADSCALE_USER_DATA_TEMPLATE}" \
  "${HEADSCALE_META_DATA_TEMPLATE}" \
  "${PACKER_TEMPLATE}"
do
  if [[ ! -f "${required}" ]]; then
    echo "missing ${required}" >&2
    exit 1
  fi
done

render_headscale_config() {
  local rendered_nameservers

  rendered_nameservers="$(
    read -r -a resolver_addrs <<< "${HEADSCALE_GLOBAL_DNS_RESOLVERS}"
    for resolver in "${resolver_addrs[@]}"; do
      printf '    - %s\n' "${resolver}"
    done
  )"

  sed \
    -e "s|__HEADSCALE_SERVER_URL__|${HEADSCALE_SERVER_URL}|g" \
    -e "s|__HEADSCALE_LISTEN_ADDR__|${HEADSCALE_LISTEN_ADDR}|g" \
    -e "s|__HEADSCALE_METRICS_LISTEN_ADDR__|${HEADSCALE_METRICS_LISTEN_ADDR}|g" \
    -e "s|__HEADSCALE_GRPC_LISTEN_ADDR__|${HEADSCALE_GRPC_LISTEN_ADDR}|g" \
    -e "s|__HEADSCALE_PREFIX_V4__|${HEADSCALE_PREFIX_V4}|g" \
    -e "s|__HEADSCALE_PREFIX_V6__|${HEADSCALE_PREFIX_V6}|g" \
    -e "s|__HEADSCALE_BASE_DOMAIN__|${HEADSCALE_BASE_DOMAIN}|g" \
    "${HEADSCALE_TEMPLATE}" \
    | RENDERED_HEADSCALE_NAMESERVERS="${rendered_nameservers}" python3 -c '
import os
import sys

content = sys.stdin.read()
print(content.replace("__HEADSCALE_GLOBAL_DNS_RESOLVERS__", os.environ["RENDERED_HEADSCALE_NAMESERVERS"]), end="")
' > "${HEADSCALE_RENDERED_CONFIG}"
}

render_cloud_init_seed() {
  local public_key escaped_public_key

  public_key="$(<"${HEADSCALE_PACKER_SSH_PUBLIC_KEY}")"
  escaped_public_key="${public_key//|/\\|}"

  sed \
    -e "s|__PACKER_SSH_USERNAME__|${HEADSCALE_PACKER_SSH_USERNAME}|g" \
    -e "s|__PACKER_SSH_PUBLIC_KEY__|${escaped_public_key}|g" \
    "${HEADSCALE_USER_DATA_TEMPLATE}" > "${HEADSCALE_RENDERED_USER_DATA}"

  sed \
    -e "s|__HEADSCALE_IMAGE_HOSTNAME__|${HEADSCALE_IMAGE_HOSTNAME}|g" \
    -e "s|__HEADSCALE_IMAGE_INSTANCE_ID__|${HEADSCALE_IMAGE_INSTANCE_ID}|g" \
    "${HEADSCALE_META_DATA_TEMPLATE}" > "${HEADSCALE_RENDERED_META_DATA}"
}

ensure_packer_ssh_key() {
  if [[ -f "${HEADSCALE_PACKER_SSH_KEY}" && -f "${HEADSCALE_PACKER_SSH_PUBLIC_KEY}" ]]; then
    return 0
  fi

  ssh-keygen -q -t ed25519 -N "" -f "${HEADSCALE_PACKER_SSH_KEY}" >/dev/null
}

download_inputs() {
  if [[ ! -f "${HEADSCALE_BASE_IMAGE}" ]]; then
    log "Downloading ${HEADSCALE_BASE_IMAGE_URL}"
    curl -fL "${HEADSCALE_BASE_IMAGE_URL}" -o "${HEADSCALE_BASE_IMAGE}"
  fi

  if [[ ! -f "${HEADSCALE_DEB}" ]]; then
    log "Downloading ${HEADSCALE_DEB_URL}"
    curl -fL "${HEADSCALE_DEB_URL}" -o "${HEADSCALE_DEB}"
  fi
}

run_packer() {
  rm -rf "${HEADSCALE_PACKER_OUTPUT_DIR}"

  packer init "${PACKER_TEMPLATE}"
  packer build \
    -var "base_image_path=${HEADSCALE_BASE_IMAGE}" \
    -var "headscale_deb_path=${HEADSCALE_DEB}" \
    -var "headscale_config_path=${HEADSCALE_RENDERED_CONFIG}" \
    -var "user_data_path=${HEADSCALE_RENDERED_USER_DATA}" \
    -var "meta_data_path=${HEADSCALE_RENDERED_META_DATA}" \
    -var "output_directory=${HEADSCALE_PACKER_OUTPUT_DIR}" \
    -var "output_image_name=${HEADSCALE_IMAGE_NAME}" \
    -var "ssh_username=${HEADSCALE_PACKER_SSH_USERNAME}" \
    -var "ssh_private_key_file=${HEADSCALE_PACKER_SSH_KEY}" \
    -var "qemu_binary=$(command -v qemu-system-x86_64)" \
    "${PACKER_TEMPLATE}"
}

install_artifact() {
  local built_image

  built_image="${HEADSCALE_PACKER_OUTPUT_DIR}/${HEADSCALE_IMAGE_NAME}"
  if [[ ! -f "${built_image}" ]]; then
    echo "expected Packer artifact not found: ${built_image}" >&2
    exit 1
  fi

  cp "${built_image}" "${HEADSCALE_IMAGE_OUTPUT}"
}

download_inputs
ensure_packer_ssh_key
render_headscale_config
render_cloud_init_seed
run_packer
install_artifact

log "Headscale base image ready: ${HEADSCALE_IMAGE_OUTPUT}"
