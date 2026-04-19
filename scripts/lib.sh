#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${STATE_DIR:-${ROOT_DIR}/.state}"
ENV_FILE="${ROOT_DIR}/.env"

load_env() {
  if [[ -f "${ENV_FILE}" ]]; then
    local line name value
    while IFS= read -r line || [[ -n "${line}" ]]; do
      [[ "${line}" =~ ^[[:space:]]*$ ]] && continue
      [[ "${line}" =~ ^[[:space:]]*# ]] && continue
      name="${line%%=*}"
      value="${line#*=}"
      [[ "${name}" == "${line}" ]] && continue
      if [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
        value="${value:1:${#value}-2}"
      elif [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
        value="${value:1:${#value}-2}"
      fi
      if [[ -z "${!name+x}" ]]; then
        export "${name}=${value}"
      fi
    done < "${ENV_FILE}"
  fi

  : "${CLUSTER_NAME:=talos-tailnet-local}"
  : "${TALOS_VERSION:=v1.11.5}"
  : "${KUBERNETES_VERSION:=1.34.1}"
  : "${TAILSCALE_CIDR:=100.64.0.0/10}"
  : "${CONTROL_PLANE_NODE_NAMES:=${NODE_NAMES:-talos-ts-cp1 talos-ts-cp2 talos-ts-cp3}}"
  : "${WORKER_NODE_NAMES:=}"
  NODE_NAMES="${CONTROL_PLANE_NODE_NAMES}${WORKER_NODE_NAMES:+ ${WORKER_NODE_NAMES}}"
  : "${CONTROL_PLANE_ENDPOINT:=https://talos-ts-cp1:6443}"
  : "${VM_MEMORY_MIB:=4096}"
  : "${VM_CPUS:=2}"
  : "${VM_CPU_MODEL:=max}"
  : "${VM_DISK_GIB:=20}"
  : "${INSTALL_DISK:=/dev/vda}"
  : "${HOST_API_BASE_PORT:=50001}"
  : "${HOST_K8S_BASE_PORT:=64431}"
  : "${VM_DISPLAY_BACKEND:=vnc}"
  : "${HOST_VNC_BASE_DISPLAY:=1}"
  : "${VM_DISPLAY_DEVICE:=VGA}"
  if [[ -z "${VM_DISPLAY_WIDTH+x}" ]]; then
    VM_DISPLAY_WIDTH=""
  fi
  if [[ -z "${VM_DISPLAY_HEIGHT+x}" ]]; then
    VM_DISPLAY_HEIGHT=""
  fi
  : "${ARGOCD_VERSION:=v3.3.6}"
  : "${ARGOCD_NAMESPACE:=argocd}"
  : "${ARGOCD_TARGET_REVISION:=main}"
  : "${ARGOCD_ROOT_PATH:=gitops/clusters/${CLUSTER_NAME}/root}"
  if [[ -z "${ARGOCD_REPO_URL+x}" ]]; then
    ARGOCD_REPO_URL="$(git -C "${ROOT_DIR}" config --get remote.origin.url 2>/dev/null || true)"
    if [[ "${ARGOCD_REPO_URL}" =~ ^git@github.com:(.+)$ ]]; then
      ARGOCD_REPO_URL="https://github.com/${BASH_REMATCH[1]}"
    fi
  fi

  read -r -a CONTROL_PLANE_NODES <<< "${CONTROL_PLANE_NODE_NAMES}"
  read -r -a WORKER_NODES <<< "${WORKER_NODE_NAMES}"
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

vnc_display_for_index() {
  echo "$((HOST_VNC_BASE_DISPLAY + $1 - 1))"
}

vnc_port_for_index() {
  echo "$((5900 + $(vnc_display_for_index "$1")))"
}

state_path() {
  echo "${STATE_DIR}/$1"
}

ensure_state_dir() {
  mkdir -p "${STATE_DIR}/"{assets,argocd,disks,logs,patches,talos,kubeconfig}
}

log() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}
