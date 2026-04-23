#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env
require_cmd kubectl

KUBECONFIG="${KUBECONFIG:-$(state_path kubeconfig/config)}"
BACKUP_DIR="${SEALED_SECRETS_BACKUP_DIR:-$(state_path backups)}"
BACKUP_FILE="${SEALED_SECRETS_BACKUP_FILE:-${BACKUP_DIR}/sealed-secrets-key.yaml}"
OPTIONAL="${SEALED_SECRETS_RESTORE_OPTIONAL:-false}"

if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "missing ${KUBECONFIG}; run make bootstrap first" >&2
  exit 1
fi

if [[ ! -f "${BACKUP_FILE}" ]]; then
  if [[ "${OPTIONAL}" == "true" ]]; then
    log "No Sealed Secrets key backup found at ${BACKUP_FILE}; controller will create one on first start"
    exit 0
  fi
  echo "missing Sealed Secrets key backup: ${BACKUP_FILE}" >&2
  echo "set SEALED_SECRETS_BACKUP_FILE=/path/to/sealed-secrets-key.yaml or run make sealed-secrets-backup on an existing cluster first" >&2
  exit 1
fi

if ! grep -Fq "sealedsecrets.bitnami.com/sealed-secrets-key" "${BACKUP_FILE}"; then
  echo "backup does not contain a Sealed Secrets key label: ${BACKUP_FILE}" >&2
  exit 1
fi

if ! grep -Fq "tls.key" "${BACKUP_FILE}"; then
  echo "backup does not contain tls.key: ${BACKUP_FILE}" >&2
  exit 1
fi

export KUBECONFIG
log "Restoring Sealed Secrets private key from ${BACKUP_FILE}"
kubectl create namespace sealed-secrets --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "${BACKUP_FILE}"
