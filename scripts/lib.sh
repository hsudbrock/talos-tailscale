#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT_DIR}/.state"
ENV_FILE="${ROOT_DIR}/.env"

load_env() {
  if [[ -f "${ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    set -a
    source "${ENV_FILE}"
    set +a
  fi

  : "${CLUSTER_NAME:=talos-tailnet-local}"
  : "${TALOS_VERSION:=v1.11.5}"
  : "${KUBERNETES_VERSION:=1.34.1}"
  : "${TAILSCALE_CIDR:=100.64.0.0/10}"
  : "${NODE_NAMES:=talos-ts-cp1 talos-ts-cp2 talos-ts-cp3}"
  : "${CONTROL_PLANE_ENDPOINT:=https://talos-ts-cp1:6443}"
  : "${VM_MEMORY_MIB:=4096}"
  : "${VM_CPUS:=2}"
  : "${VM_DISK_GIB:=20}"
  : "${HOST_API_BASE_PORT:=50001}"
  : "${HOST_K8S_BASE_PORT:=64431}"

  read -r -a NODES <<< "${NODE_NAMES}"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "missing required command: ${cmd}" >&2
    exit 1
  fi
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "missing required environment variable: ${name}" >&2
    exit 1
  fi
}

node_index() {
  local node="$1"
  local i
  for i in "${!NODES[@]}"; do
    if [[ "${NODES[$i]}" == "${node}" ]]; then
      echo "$((i + 1))"
      return 0
    fi
  done
  echo "unknown node: ${node}" >&2
  exit 1
}

api_port_for_index() {
  echo "$((HOST_API_BASE_PORT + $1 - 1))"
}

k8s_port_for_index() {
  echo "$((HOST_K8S_BASE_PORT + $1 - 1))"
}

state_path() {
  echo "${STATE_DIR}/$1"
}

ensure_state_dir() {
  mkdir -p "${STATE_DIR}/"{assets,disks,logs,patches,talos,kubeconfig}
}

log() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}
