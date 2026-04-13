#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env
require_cmd talosctl
require_cmd kubectl

TALOSCONFIG="$(state_path talos/generated/talosconfig)"
KUBECONFIG="$(state_path kubeconfig/config)"

if [[ ! -f "${TALOSCONFIG}" ]]; then
  echo "missing ${TALOSCONFIG}; run scripts/generate-configs.sh first" >&2
  exit 1
fi

if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "missing ${KUBECONFIG}; run scripts/bootstrap.sh first" >&2
  exit 1
fi

export TALOSCONFIG
export KUBECONFIG

NODE_ARGS=()
for node in "${NODES[@]}"; do
  NODE_ARGS+=(--nodes "${node}")
done

log "Checking Talos API over Tailscale hostnames"
talosctl "${NODE_ARGS[@]}" version

log "Checking Tailscale extension service"
talosctl "${NODE_ARGS[@]}" service ext-tailscale

log "Checking etcd health"
talosctl "${NODE_ARGS[@]}" etcd members

log "Checking Kubernetes nodes and InternalIPs"
kubectl get nodes -o wide

log "Applying cross-node smoke workload"
kubectl apply -f "${ROOT_DIR}/config/kubernetes/cross-node-smoke.yaml"
kubectl rollout status deployment/tailnet-smoke --timeout=5m

log "Checking smoke pods distribution"
kubectl get pods -l app=tailnet-smoke -o wide

log "Checking smoke service reachability from an in-cluster curl pod"
kubectl run tailnet-curl \
  --rm \
  -i \
  --restart=Never \
  --image=curlimages/curl:8.11.1 \
  --command -- curl -fsS http://tailnet-smoke.default.svc.cluster.local/
