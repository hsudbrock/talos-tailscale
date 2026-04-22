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

VALIDATE_CURL_MANIFEST="$(mktemp)"

cleanup_smoke_workload() {
  kubectl delete -f "${ROOT_DIR}/config/kubernetes/cross-node-smoke.yaml" --ignore-not-found >/dev/null
  kubectl delete -f "${VALIDATE_CURL_MANIFEST}" --ignore-not-found >/dev/null 2>&1 || true
  rm -f "${VALIDATE_CURL_MANIFEST}"
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
cat > "${VALIDATE_CURL_MANIFEST}" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: tailnet-curl
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    runAsGroup: 65532
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: curl
      image: curlimages/curl:8.11.1
      command:
        - curl
        - -fsS
        - http://tailnet-smoke.default.svc.cluster.local/
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
YAML

kubectl apply -f "${VALIDATE_CURL_MANIFEST}"
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/tailnet-curl --timeout=2m >/dev/null
kubectl logs tailnet-curl
kubectl delete -f "${VALIDATE_CURL_MANIFEST}" >/dev/null
