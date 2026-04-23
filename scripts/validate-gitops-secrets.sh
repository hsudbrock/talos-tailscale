#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GITOPS_DIR="${ROOT_DIR}/gitops"

if [[ ! -d "${GITOPS_DIR}" ]]; then
  echo "missing ${GITOPS_DIR}" >&2
  exit 1
fi

status=0

while IFS= read -r -d '' file; do
  if grep -Eq '^[[:space:]]*kind:[[:space:]]*Secret[[:space:]]*$' "${file}"; then
    echo "${file}: plaintext Kubernetes Secret manifests are not allowed in gitops; commit a SealedSecret instead" >&2
    status=1
  fi

  if grep -Eq '^[[:space:]]*stringData:[[:space:]]*$' "${file}"; then
    echo "${file}: stringData is plaintext secret material and is not allowed in gitops" >&2
    status=1
  fi

  if grep -Eiq '(^|[^A-Za-z0-9])(password|passwd|token|api[-_]?key|client[-_]?secret):[[:space:]]*("|'\'')?(changeme|change-me|replace-me|replace_me|todo|example|dummy|secret|password|token)("|'\'')?[[:space:]]*$' "${file}"; then
    echo "${file}: found an obvious plaintext secret placeholder" >&2
    status=1
  fi

  if grep -Eq '^[[:space:]]*encryptedData:[[:space:]]*$' "${file}" &&
    grep -Eq '^[[:space:]]*(password|passwd|token|api[-_]?key|client[-_]?secret):[[:space:]]*(changeme|replace-me|replace_me|todo|example|dummy|secret|password|token)[[:space:]]*$' "${file}"; then
    echo "${file}: encryptedData contains a placeholder instead of sealed ciphertext" >&2
    status=1
  fi
done < <(find "${GITOPS_DIR}" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

exit "${status}"
