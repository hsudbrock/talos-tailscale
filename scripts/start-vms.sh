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
  vnc_display="$(vnc_display_for_index "${idx}")"
  vnc_port="$(vnc_port_for_index "${idx}")"
  display_device_args=(-device "${VM_DISPLAY_DEVICE}")
  display_args=(-display "vnc=127.0.0.1:${vnc_display}" -daemonize -pidfile "${pidfile}")
  display_label="VNC localhost:${vnc_port}"
  if [[ -n "${VM_DISPLAY_WIDTH}" && -n "${VM_DISPLAY_HEIGHT}" ]]; then
    display_device_args=(-device "${VM_DISPLAY_DEVICE},xres=${VM_DISPLAY_WIDTH},yres=${VM_DISPLAY_HEIGHT}")
  fi
  if [[ "${VM_DISPLAY_BACKEND}" == "gtk" ]]; then
    display_args=(-display "gtk,zoom-to-fit=on,show-menubar=on" -pidfile "${pidfile}")
    display_label="GTK window"
  elif [[ "${VM_DISPLAY_BACKEND}" != "vnc" ]]; then
    echo "unsupported VM_DISPLAY_BACKEND=${VM_DISPLAY_BACKEND}; expected vnc or gtk" >&2
    exit 1
  fi

  if [[ -f "${pidfile}" ]] && kill -0 "$(<"${pidfile}")" 2>/dev/null; then
    log "${node} already running with pid $(<"${pidfile}")"
    continue
  fi

  if [[ ! -f "${disk}" ]]; then
    qemu-img create -f qcow2 "${disk}" "${VM_DISK_GIB}G" >/dev/null
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
    -cdrom "${ISO_FILE}" \
    -boot order=d \
    -netdev "user,id=net${idx},hostname=${node},hostfwd=tcp:127.0.0.1:${api_port}-:50000,hostfwd=tcp:127.0.0.1:${k8s_port}-:6443" \
    -device "virtio-net-pci,netdev=net${idx}" \
    "${display_device_args[@]}" \
    -serial "file:${log_file}" \
    "${display_args[@]}"
  )

  if [[ "${VM_DISPLAY_BACKEND}" == "gtk" ]]; then
    "${qemu_cmd[@]}" &
  else
    "${qemu_cmd[@]}"
  fi
done

log "VMs are isolated by QEMU user-mode networking; no shared bridge is created."
