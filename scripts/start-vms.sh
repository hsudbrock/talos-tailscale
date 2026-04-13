#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env
ensure_state_dir
require_cmd qemu-system-x86_64
require_cmd qemu-img

ISO_FILE="$(state_path "assets/talos-${TALOS_VERSION}-tailscale-metal-amd64.iso")"
if [[ ! -f "${ISO_FILE}" ]]; then
  echo "missing ${ISO_FILE}; run scripts/prepare-image.sh first" >&2
  exit 1
fi

for node in "${NODES[@]}"; do
  idx="$(node_index "${node}")"
  disk="$(state_path "disks/${node}.qcow2")"
  pidfile="$(state_path "${node}.pid")"
  log_file="$(state_path "logs/${node}.log")"
  api_port="$(api_port_for_index "${idx}")"
  k8s_port="$(k8s_port_for_index "${idx}")"

  if [[ -f "${pidfile}" ]] && kill -0 "$(<"${pidfile}")" 2>/dev/null; then
    log "${node} already running with pid $(<"${pidfile}")"
    continue
  fi

  if [[ ! -f "${disk}" ]]; then
    qemu-img create -f qcow2 "${disk}" "${VM_DISK_GIB}G" >/dev/null
  fi

  log "Starting ${node}; Talos API localhost:${api_port}, Kubernetes localhost:${k8s_port}"
  qemu-system-x86_64 \
    -name "${node}" \
    -machine accel=kvm:tcg \
    -smp "${VM_CPUS}" \
    -m "${VM_MEMORY_MIB}" \
    -drive "file=${disk},format=qcow2,if=virtio" \
    -cdrom "${ISO_FILE}" \
    -boot order=d \
    -netdev "user,id=net${idx},hostname=${node},hostfwd=tcp:127.0.0.1:${api_port}-:50000,hostfwd=tcp:127.0.0.1:${k8s_port}-:6443" \
    -device "virtio-net-pci,netdev=net${idx}" \
    -serial "file:${log_file}" \
    -display none \
    -daemonize \
    -pidfile "${pidfile}"
done

log "VMs are isolated by QEMU user-mode networking; no shared bridge is created."
