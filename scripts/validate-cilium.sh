#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env
require_cmd kubectl

KUBECONFIG="$(state_path kubeconfig/config)"
if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "missing ${KUBECONFIG}; run scripts/bootstrap.sh first" >&2
  exit 1
fi
export KUBECONFIG

TMP_DIR="$(mktemp -d)"
WORKLOAD_FILE="${TMP_DIR}/workload.yaml"
POLICY_FILE="${TMP_DIR}/policy.yaml"

cleanup() {
  kubectl delete namespace policy-smoke --ignore-not-found >/dev/null 2>&1 || true
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

cat > "${WORKLOAD_FILE}" <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: policy-smoke
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo
  namespace: policy-smoke
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo
  template:
    metadata:
      labels:
        app: echo
    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: echo
          image: hashicorp/http-echo:1.0.0
          args:
            - -text=policy ok
            - -listen=:5678
          ports:
            - containerPort: 5678
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            runAsNonRoot: true
            runAsUser: 65532
            runAsGroup: 65532
---
apiVersion: v1
kind: Service
metadata:
  name: echo
  namespace: policy-smoke
spec:
  selector:
    app: echo
  ports:
    - port: 80
      targetPort: 5678
---
apiVersion: v1
kind: Pod
metadata:
  name: allowed-client
  namespace: policy-smoke
  labels:
    access: allowed
spec:
  restartPolicy: Never
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: curl
      image: curlimages/curl:8.11.1
      command:
        - sleep
        - infinity
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
        runAsNonRoot: true
        runAsUser: 65532
        runAsGroup: 65532
---
apiVersion: v1
kind: Pod
metadata:
  name: denied-client
  namespace: policy-smoke
  labels:
    access: denied
spec:
  restartPolicy: Never
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: curl
      image: curlimages/curl:8.11.1
      command:
        - sleep
        - infinity
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
        runAsNonRoot: true
        runAsUser: 65532
        runAsGroup: 65532
YAML

cat > "${POLICY_FILE}" <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: policy-smoke
spec:
  podSelector: {}
  policyTypes:
    - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-echo-from-allowed-client
  namespace: policy-smoke
spec:
  podSelector:
    matchLabels:
      app: echo
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              access: allowed
      ports:
        - protocol: TCP
          port: 5678
YAML

log "Deploying Cilium policy smoke workload"
kubectl apply -f "${WORKLOAD_FILE}" >/dev/null
kubectl rollout status deployment/echo -n policy-smoke --timeout=5m >/dev/null
kubectl wait --for=condition=Ready pod/allowed-client pod/denied-client -n policy-smoke --timeout=2m >/dev/null

log "Applying standard Kubernetes NetworkPolicies"
kubectl apply -f "${POLICY_FILE}" >/dev/null
sleep 5

log "Validating allowed traffic"
allowed_output="$(kubectl exec -n policy-smoke allowed-client -- curl -fsS --max-time 10 http://echo.policy-smoke.svc.cluster.local/)"
printf '%s\n' "${allowed_output}"
if [[ "${allowed_output}" != "policy ok" ]]; then
  echo "unexpected allowed client response: ${allowed_output}" >&2
  exit 1
fi

log "Validating denied traffic"
if kubectl exec -n policy-smoke denied-client -- curl -fsS --max-time 10 http://echo.policy-smoke.svc.cluster.local/ >/dev/null 2>&1; then
  echo "denied client unexpectedly reached the echo service" >&2
  exit 1
fi

node_name="$(kubectl get pod allowed-client -n policy-smoke -o jsonpath='{.spec.nodeName}')"
cilium_pod="$(kubectl -n kube-system get pods -l k8s-app=cilium -o wide --no-headers | awk -v node="${node_name}" '$7 == node { print $1; exit }')"
if [[ -z "${cilium_pod}" ]]; then
  echo "could not find cilium pod on node ${node_name}" >&2
  exit 1
fi

log "Capturing Hubble flow output"
flow_output="$(kubectl exec -n kube-system "${cilium_pod}" -c cilium-agent -- hubble observe --since 5m --namespace policy-smoke --last 100)"
printf '%s\n' "${flow_output}"
if [[ "${flow_output}" != *"FORWARDED"* || "${flow_output}" != *"DROPPED"* || "${flow_output}" != *"policy-smoke/allowed-client"* || "${flow_output}" != *"policy-smoke/denied-client"* || "${flow_output}" != *"Policy denied"* ]]; then
  echo "Hubble output did not contain the expected forwarded and dropped policy-smoke flows" >&2
  exit 1
fi

log "Cilium policy and Hubble validation passed"
