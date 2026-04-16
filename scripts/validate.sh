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

cleanup_smoke_workload() {
  kubectl delete -f "${ROOT_DIR}/config/kubernetes/cross-node-smoke.yaml" --ignore-not-found >/dev/null
}

trap cleanup_smoke_workload EXIT

log "Checking Talos API over Tailscale hostnames"
for node in "${NODES[@]}"; do
  talosctl --endpoints "${node}" --nodes "${node}" version
done

log "Checking Tailscale extension service"
for node in "${NODES[@]}"; do
  talosctl --endpoints "${node}" --nodes "${node}" service ext-tailscale
done

log "Checking etcd health"
talosctl --endpoints "${CONTROL_PLANE_NODES[0]}" --nodes "${CONTROL_PLANE_NODES[0]}" etcd members

log "Checking Kubernetes nodes and InternalIPs"
kubectl get nodes -o wide

log "Applying smoke workload"
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
