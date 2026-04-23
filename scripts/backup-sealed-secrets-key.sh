#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_env
require_cmd kubectl

KUBECONFIG="${KUBECONFIG:-$(state_path kubeconfig/config)}"
BACKUP_DIR="${SEALED_SECRETS_BACKUP_DIR:-$(state_path backups)}"
BACKUP_FILE="${SEALED_SECRETS_BACKUP_FILE:-${BACKUP_DIR}/sealed-secrets-key.yaml}"
FORCE="${SEALED_SECRETS_BACKUP_FORCE:-false}"

if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "missing ${KUBECONFIG}; run make bootstrap first" >&2
  exit 1
fi

if [[ -f "${BACKUP_FILE}" && "${FORCE}" != "true" ]]; then
  echo "refusing to overwrite existing backup: ${BACKUP_FILE}" >&2
  echo "set SEALED_SECRETS_BACKUP_FORCE=true to overwrite it" >&2
  exit 1
fi

mkdir -p "${BACKUP_DIR}"
chmod 700 "${BACKUP_DIR}"

export KUBECONFIG
kubectl get secret -n sealed-secrets \
  -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o yaml > "${BACKUP_FILE}"

chmod 600 "${BACKUP_FILE}"

if ! grep -Fq "sealedsecrets.bitnami.com/sealed-secrets-key" "${BACKUP_FILE}"; then
  echo "backup did not contain a Sealed Secrets key label: ${BACKUP_FILE}" >&2
  exit 1
fi

if ! grep -Fq "tls.key" "${BACKUP_FILE}"; then
  echo "backup did not contain tls.key: ${BACKUP_FILE}" >&2
  exit 1
fi

echo "Backed up Sealed Secrets private key to ${BACKUP_FILE}"
echo "This file can decrypt committed SealedSecret objects. Store an encrypted copy outside this repo."
