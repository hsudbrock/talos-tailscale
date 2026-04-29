#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${STATE_DIR:-${ROOT_DIR}/.state}"
ENV_FILE="${ROOT_DIR}/.env"

normalize_node_name_suffix() {
  local suffix="$1"

  if [[ -z "${suffix}" || "${suffix}" == "random" ]]; then
    echo "${suffix}"
    return 0
  fi

  if [[ "${suffix}" == -* ]]; then
    echo "${suffix}"
    return 0
  fi

  echo "-${suffix}"
}

generate_random_node_name_suffix() {
  local raw

  if command -v uuidgen >/dev/null 2>&1; then
    raw="$(uuidgen)"
  elif [[ -r /proc/sys/kernel/random/uuid ]]; then
    raw="$(</proc/sys/kernel/random/uuid)"
  else
    raw="$(date +%s%N)"
  fi

  raw="${raw,,}"
  raw="${raw//[^a-z0-9]/}"
  echo "-${raw:0:8}"
}

resolve_node_name_suffix() {
  local suffix="$1"
  local suffix_file resolved

  if [[ "${suffix}" != "random" ]]; then
    echo "${suffix}"
    return 0
  fi

  mkdir -p "${STATE_DIR}"
  suffix_file="${STATE_DIR}/node-name-suffix"
  if [[ -f "${suffix_file}" ]]; then
    cat "${suffix_file}"
    return 0
  fi

  resolved="$(generate_random_node_name_suffix)"
  printf '%s\n' "${resolved}" > "${suffix_file}"
  echo "${resolved}"
}

append_node_suffixes() {
  local names="$1"
  local suffix="$2"
  local result=()
  local node

  if [[ -z "${names}" || -z "${suffix}" ]]; then
    echo "${names}"
    return 0
  fi

  read -r -a nodes <<< "${names}"
  for node in "${nodes[@]}"; do
    result+=("${node}${suffix}")
  done

  printf '%s' "${result[*]}"
}

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
  : "${CLUSTER_CNI:=cilium}"
  : "${CILIUM_VERSION:=1.19.3}"
  : "${TAILSCALE_CIDR:=100.64.0.0/10}"
  : "${TAILSCALE_ACCEPT_DNS:=false}"
  : "${TAILSCALE_DNS_RESOLVERS:=100.100.100.100 9.9.9.9 1.1.1.1 8.8.8.8}"
  : "${TAILSCALE_SEARCH_DOMAIN:=}"
  : "${NODE_NAME_SUFFIX:=}"
  local base_control_plane_node_names base_worker_node_names control_plane_endpoint_base first_control_plane_node resolved_node_name_suffix

  : "${BASE_CONTROL_PLANE_NODE_NAMES:=${CONTROL_PLANE_NODE_NAMES:-${NODE_NAMES:-talos-ts-cp1 talos-ts-cp2 talos-ts-cp3}}}"
  : "${BASE_WORKER_NODE_NAMES:=${WORKER_NODE_NAMES:-}}"
  export BASE_CONTROL_PLANE_NODE_NAMES BASE_WORKER_NODE_NAMES
  base_control_plane_node_names="${BASE_CONTROL_PLANE_NODE_NAMES}"
  base_worker_node_names="${BASE_WORKER_NODE_NAMES}"
  resolved_node_name_suffix="$(normalize_node_name_suffix "${NODE_NAME_SUFFIX}")"
  resolved_node_name_suffix="$(resolve_node_name_suffix "${resolved_node_name_suffix}")"
  NODE_NAME_SUFFIX_RESOLVED="${resolved_node_name_suffix}"
  export NODE_NAME_SUFFIX_RESOLVED
  CONTROL_PLANE_NODE_NAMES="$(append_node_suffixes "${base_control_plane_node_names}" "${resolved_node_name_suffix}")"
  WORKER_NODE_NAMES="$(append_node_suffixes "${base_worker_node_names}" "${resolved_node_name_suffix}")"
  NODE_NAMES="${CONTROL_PLANE_NODE_NAMES}${WORKER_NODE_NAMES:+ ${WORKER_NODE_NAMES}}"
  read -r -a _control_plane_nodes <<< "${CONTROL_PLANE_NODE_NAMES}"
  first_control_plane_node="${_control_plane_nodes[0]}"
  read -r -a _base_control_plane_nodes <<< "${base_control_plane_node_names}"
  control_plane_endpoint_base="https://${_base_control_plane_nodes[0]}:6443"
  if [[ -z "${CONTROL_PLANE_ENDPOINT+x}" || "${CONTROL_PLANE_ENDPOINT}" == "${control_plane_endpoint_base}" ]]; then
    CONTROL_PLANE_ENDPOINT="https://${first_control_plane_node}:6443"
  fi
  : "${VM_MEMORY_MIB:=4096}"
  : "${VM_CPUS:=2}"
  : "${VM_CPU_MODEL:=max}"
  : "${VM_DISK_GIB:=20}"
  : "${WORKER_DATA_DISK_GIB:=20}"
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
  : "${LONGHORN_NAMESPACE:=longhorn-system}"
  : "${LONGHORN_APP_NAME:=longhorn}"
  : "${LONGHORN_VOLUME_NAME:=longhorn}"
  : "${LONGHORN_DISK_SELECTOR:=disk.dev_path == \"/dev/vdb\"}"
  : "${LONGHORN_VOLUME_MAX_SIZE:=16GiB}"
  : "${HEADSCALE_BOOTSTRAP_MODE:=disabled}"
  : "${HEADSCALE_VM_NAME:=headscale}"
  : "${HEADSCALE_VM_IMAGE:=}"
  : "${HEADSCALE_VM_DISK:=}"
  : "${HEADSCALE_VM_MEMORY_MIB:=2048}"
  : "${HEADSCALE_VM_CPUS:=2}"
  : "${HEADSCALE_VM_CPU_MODEL:=${VM_CPU_MODEL}}"
  : "${HEADSCALE_HOST_HTTP_PORT:=18080}"
  : "${HEADSCALE_GUEST_HTTP_PORT:=8080}"
  : "${HEADSCALE_HOST_SSH_PORT:=10022}"
  : "${HEADSCALE_GUEST_SSH_PORT:=22}"
  : "${HEADSCALE_READY_TIMEOUT_SECONDS:=180}"
  : "${HEADSCALE_READY_INTERVAL_SECONDS:=2}"
  : "${HEADSCALE_VERSION:=0.28.0}"
  : "${HEADSCALE_ARCH:=amd64}"
  : "${HEADSCALE_BASE_IMAGE_URL:=https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2}"
  : "${HEADSCALE_DEB_URL:=https://github.com/juanfont/headscale/releases/download/v${HEADSCALE_VERSION}/headscale_${HEADSCALE_VERSION}_linux_${HEADSCALE_ARCH}.deb}"
  : "${HEADSCALE_SERVER_URL:=http://headscale.example.internal:8080}"
  : "${HEADSCALE_LISTEN_ADDR:=0.0.0.0:8080}"
  : "${HEADSCALE_METRICS_LISTEN_ADDR:=127.0.0.1:9090}"
  : "${HEADSCALE_GRPC_LISTEN_ADDR:=127.0.0.1:50443}"
  : "${HEADSCALE_PREFIX_V4:=100.64.0.0/10}"
  : "${HEADSCALE_PREFIX_V6:=fd7a:115c:a1e0::/48}"
  : "${HEADSCALE_BASE_DOMAIN:=headscale.invalid}"
  : "${HEADSCALE_PACKER_SSH_USERNAME:=packer}"
  : "${HEADSCALE_IMAGE_HOSTNAME:=headscale-image}"
  : "${HEADSCALE_IMAGE_INSTANCE_ID:=headscale-image}"
  if [[ -z "${ARGOCD_REPO_URL+x}" ]]; then
    ARGOCD_REPO_URL="$(git -C "${ROOT_DIR}" config --get remote.origin.url 2>/dev/null || true)"
    if [[ "${ARGOCD_REPO_URL}" =~ ^git@github.com:(.+)$ ]]; then
      ARGOCD_REPO_URL="https://github.com/${BASH_REMATCH[1]}"
    fi
  fi

  read -r -a CONTROL_PLANE_NODES <<< "${CONTROL_PLANE_NODE_NAMES}"
  read -r -a WORKER_NODES <<< "${WORKER_NODE_NAMES}"
  read -r -a NODES <<< "${NODE_NAMES}"

  if [[ -z "${HEADSCALE_VM_DISK}" ]]; then
    HEADSCALE_VM_DISK="$(state_path "disks/${HEADSCALE_VM_NAME}.qcow2")"
  fi
  export HEADSCALE_VM_DISK

  if [[ -z "${HEADSCALE_IMAGE_OUTPUT+x}" ]]; then
    HEADSCALE_IMAGE_OUTPUT="$(state_path headscale/headscale-base.qcow2)"
  fi
  export HEADSCALE_IMAGE_OUTPUT

  if [[ -z "${HEADSCALE_URL+x}" || -z "${HEADSCALE_URL}" ]]; then
    case "${HEADSCALE_BOOTSTRAP_MODE}" in
      local-vm)
        HEADSCALE_URL="http://10.0.2.2:${HEADSCALE_HOST_HTTP_PORT}"
        ;;
      *)
        HEADSCALE_URL=""
        ;;
    esac
  fi
  export HEADSCALE_URL
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

headscale_local_vm_enabled() {
  [[ "${HEADSCALE_BOOTSTRAP_MODE}" == "local-vm" ]]
}

headscale_support_enabled() {
  [[ "${HEADSCALE_BOOTSTRAP_MODE}" == "local-vm" || "${HEADSCALE_BOOTSTRAP_MODE}" == "external" ]]
}

require_node() {
  local node="$1"
  local known

  for known in "${NODES[@]}"; do
    if [[ "${known}" == "${node}" ]]; then
      return 0
    fi
  done

  echo "unknown node: ${node}" >&2
  echo "known nodes: ${NODES[*]}" >&2
  exit 1
}

is_worker_node() {
  local node="$1"
  local worker

  for worker in "${WORKER_NODES[@]}"; do
    if [[ "${worker}" == "${node}" ]]; then
      return 0
    fi
  done

  return 1
}

start_vm() {
  local node="$1"
  local idx disk worker_data_disk pidfile log_file qemu_log_file api_port k8s_port vnc_display vnc_port
  local display_label
  local display_device_args display_args qemu_cmd extra_drive_args

  require_node "${node}"
  ensure_state_dir
  require_cmd qemu-system-x86_64
  require_cmd qemu-img

  ISO_FILE="$(state_path "assets/talos-${TALOS_VERSION}-tailscale-metal-amd64.iso")"
  if [[ ! -f "${ISO_FILE}" ]]; then
    echo "missing ${ISO_FILE}; run scripts/prepare-image.sh first" >&2
    exit 1
  fi

  idx="$(node_index "${node}")"
  disk="$(state_path "disks/${node}.qcow2")"
  worker_data_disk="$(state_path "disks/${node}-data.qcow2")"
  pidfile="$(state_path "${node}.pid")"
  log_file="$(state_path "logs/${node}.log")"
  qemu_log_file="$(state_path "logs/${node}.qemu.log")"
  api_port="$(api_port_for_index "${idx}")"
  k8s_port="$(k8s_port_for_index "${idx}")"
  vnc_display="$(vnc_display_for_index "${idx}")"
  vnc_port="$(vnc_port_for_index "${idx}")"
  display_device_args=(-device "${VM_DISPLAY_DEVICE}")
  display_args=(-display "vnc=127.0.0.1:${vnc_display}" -daemonize -pidfile "${pidfile}")
  display_label="VNC localhost:${vnc_port}"

  if [[ -n "${VM_DISPLAY_WIDTH}" && -n "${VM_DISPLAY_HEIGHT}" ]]; then
    display_device_args=(-device "${VM_DISPLAY_DEVICE},xres=${VM_DISPLAY_WIDTH},yres=${VM_DISPLAY_HEIGHT}")
  fi

  if [[ "${VM_DISPLAY_BACKEND}" == "gtk" ]]; then
    display_args=(-display "gtk,zoom-to-fit=on,show-menubar=on" -daemonize -pidfile "${pidfile}")
    display_label="GTK window"
  elif [[ "${VM_DISPLAY_BACKEND}" != "vnc" ]]; then
    echo "unsupported VM_DISPLAY_BACKEND=${VM_DISPLAY_BACKEND}; expected vnc or gtk" >&2
    exit 1
  fi

  if [[ -f "${pidfile}" ]] && kill -0 "$(<"${pidfile}")" 2>/dev/null; then
    log "${node} already running with pid $(<"${pidfile}")"
    return 0
  elif [[ -f "${pidfile}" ]]; then
    rm -f "${pidfile}"
  fi

  if [[ ! -f "${disk}" ]]; then
    qemu-img create -f qcow2 "${disk}" "${VM_DISK_GIB}G" >/dev/null
  fi

  extra_drive_args=()
  if is_worker_node "${node}" && (( WORKER_DATA_DISK_GIB > 0 )); then
    if [[ ! -f "${worker_data_disk}" ]]; then
      qemu-img create -f qcow2 "${worker_data_disk}" "${WORKER_DATA_DISK_GIB}G" >/dev/null
    fi
    extra_drive_args=(-drive "file=${worker_data_disk},format=qcow2,if=virtio")
  fi

  log "Starting ${node}; Talos API localhost:${api_port}, Kubernetes localhost:${k8s_port}, display ${display_label}"
  qemu_cmd=(
    qemu-system-x86_64
    -name "${node}" \
    -machine accel=kvm:tcg \
    -cpu "${VM_CPU_MODEL}" \
    -smp "${VM_CPUS}" \
    -m "${VM_MEMORY_MIB}" \
    -drive "file=${disk},format=qcow2,if=virtio" \
    "${extra_drive_args[@]}" \
    -cdrom "${ISO_FILE}" \
    -boot order=cd \
    -netdev "user,id=net${idx},hostname=${node},hostfwd=tcp:127.0.0.1:${api_port}-:50000,hostfwd=tcp:127.0.0.1:${k8s_port}-:6443" \
    -device "virtio-net-pci,netdev=net${idx}" \
    "${display_device_args[@]}" \
    -serial "file:${log_file}" \
    "${display_args[@]}"
  )

  "${qemu_cmd[@]}" 2>"${qemu_log_file}"
}

ensure_headscale_vm_disk() {
  if [[ -f "${HEADSCALE_VM_DISK}" ]]; then
    return 0
  fi

  if [[ -z "${HEADSCALE_VM_IMAGE}" ]]; then
    echo "missing ${HEADSCALE_VM_DISK}; set HEADSCALE_VM_IMAGE to a prepared Headscale base qcow2 image or point HEADSCALE_VM_DISK at an existing writable image" >&2
    exit 1
  fi

  if [[ ! -f "${HEADSCALE_VM_IMAGE}" ]]; then
    echo "missing HEADSCALE_VM_IMAGE=${HEADSCALE_VM_IMAGE}" >&2
    exit 1
  fi

  mkdir -p "$(dirname "${HEADSCALE_VM_DISK}")"
  qemu-img create -f qcow2 -F qcow2 -b "${HEADSCALE_VM_IMAGE}" "${HEADSCALE_VM_DISK}" >/dev/null
}

start_headscale_vm() {
  local pidfile log_file qemu_log_file
  local qemu_cmd

  headscale_local_vm_enabled || return 0

  ensure_state_dir
  require_cmd qemu-system-x86_64
  require_cmd qemu-img

  pidfile="$(state_path "${HEADSCALE_VM_NAME}.pid")"
  log_file="$(state_path "logs/${HEADSCALE_VM_NAME}.log")"
  qemu_log_file="$(state_path "logs/${HEADSCALE_VM_NAME}.qemu.log")"

  if [[ -f "${pidfile}" ]] && kill -0 "$(<"${pidfile}")" 2>/dev/null; then
    log "${HEADSCALE_VM_NAME} already running with pid $(<"${pidfile}")"
    return 0
  elif [[ -f "${pidfile}" ]]; then
    rm -f "${pidfile}"
  fi

  ensure_headscale_vm_disk

  log "Starting ${HEADSCALE_VM_NAME}; Headscale host forward localhost:${HEADSCALE_HOST_HTTP_PORT}, SSH localhost:${HEADSCALE_HOST_SSH_PORT}"
  qemu_cmd=(
    qemu-system-x86_64
    -name "${HEADSCALE_VM_NAME}" \
    -machine accel=kvm:tcg \
    -cpu "${HEADSCALE_VM_CPU_MODEL}" \
    -smp "${HEADSCALE_VM_CPUS}" \
    -m "${HEADSCALE_VM_MEMORY_MIB}" \
    -drive "file=${HEADSCALE_VM_DISK},format=qcow2,if=virtio" \
    -netdev "user,id=${HEADSCALE_VM_NAME},hostname=${HEADSCALE_VM_NAME},hostfwd=tcp:127.0.0.1:${HEADSCALE_HOST_HTTP_PORT}-:${HEADSCALE_GUEST_HTTP_PORT},hostfwd=tcp:127.0.0.1:${HEADSCALE_HOST_SSH_PORT}-:${HEADSCALE_GUEST_SSH_PORT}" \
    -device "virtio-net-pci,netdev=${HEADSCALE_VM_NAME}" \
    -display none \
    -serial "file:${log_file}" \
    -daemonize -pidfile "${pidfile}"
  )

  "${qemu_cmd[@]}" 2>"${qemu_log_file}"
}

stop_vm() {
  local node="$1"
  local pidfile pid

  require_node "${node}"

  pidfile="$(state_path "${node}.pid")"
  if [[ ! -f "${pidfile}" ]]; then
    log "${node} is not running"
    return 0
  fi

  pid="$(<"${pidfile}")"
  if kill -0 "${pid}" 2>/dev/null; then
    log "Stopping ${node} pid ${pid}"
    kill "${pid}"
  fi
  rm -f "${pidfile}"
}

stop_headscale_vm() {
  local pidfile pid

  headscale_local_vm_enabled || return 0

  pidfile="$(state_path "${HEADSCALE_VM_NAME}.pid")"
  if [[ ! -f "${pidfile}" ]]; then
    log "${HEADSCALE_VM_NAME} is not running"
    return 0
  fi

  pid="$(<"${pidfile}")"
  if kill -0 "${pid}" 2>/dev/null; then
    log "Stopping ${HEADSCALE_VM_NAME} pid ${pid}"
    kill "${pid}"
  fi
  rm -f "${pidfile}"
}
