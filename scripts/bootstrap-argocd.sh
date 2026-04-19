#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env
ensure_state_dir
require_cmd curl
require_cmd kubectl
require_env ARGOCD_REPO_URL

KUBECONFIG="$(state_path kubeconfig/config)"
NAMESPACE_MANIFEST="$(state_path argocd/namespace.yaml)"
INSTALL_MANIFEST="$(state_path "argocd/install-${ARGOCD_VERSION}.yaml")"
ROOT_APPLICATION="$(state_path argocd/root-application.yaml)"
INSTALL_URL="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "missing ${KUBECONFIG}; run scripts/bootstrap.sh first" >&2
  exit 1
fi

export KUBECONFIG

log "Downloading Argo CD ${ARGOCD_VERSION} install manifest"
curl -fsSL "${INSTALL_URL}" -o "${INSTALL_MANIFEST}"

log "Rendering Argo CD namespace"
cat > "${NAMESPACE_MANIFEST}" <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: ${ARGOCD_NAMESPACE}
YAML

log "Applying Argo CD namespace"
kubectl apply -f "${NAMESPACE_MANIFEST}"

log "Installing Argo CD into ${ARGOCD_NAMESPACE}"
kubectl apply -n "${ARGOCD_NAMESPACE}" --server-side --force-conflicts -f "${INSTALL_MANIFEST}" --request-timeout=5m

log "Waiting for Argo CD workloads"
kubectl rollout status deployment/argocd-server --timeout=5m -n "${ARGOCD_NAMESPACE}"
kubectl rollout status statefulset/argocd-application-controller --timeout=5m -n "${ARGOCD_NAMESPACE}"

log "Rendering root Argo CD Application"
cat > "${ROOT_APPLICATION}" <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${CLUSTER_NAME}-root
  namespace: ${ARGOCD_NAMESPACE}
spec:
  project: default
  source:
    repoURL: ${ARGOCD_REPO_URL}
    targetRevision: ${ARGOCD_TARGET_REVISION}
    path: ${ARGOCD_ROOT_PATH}
  destination:
    server: https://kubernetes.default.svc
    namespace: ${ARGOCD_NAMESPACE}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
YAML

log "Applying root Argo CD Application"
kubectl apply -f "${ROOT_APPLICATION}" --request-timeout=2m

log "Argo CD bootstrap complete. Use make argocd-status to inspect sync state."
