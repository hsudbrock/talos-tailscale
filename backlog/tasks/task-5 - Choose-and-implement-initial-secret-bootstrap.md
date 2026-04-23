---
id: TASK-5
title: Choose and implement initial secret bootstrap
status: In Progress
assignee:
  - Codex
created_date: '2026-04-19 07:18'
updated_date: '2026-04-23 14:27'
labels:
  - secrets
  - gitops
  - bootstrap
dependencies:
  - TASK-4
references:
  - 'https://github.com/getsops/sops'
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Define the first safe mechanism for committing non-public Kubernetes secret material needed by platform apps. Recommended default is SOPS with age unless implementation discovery exposes a better fit.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Decision is documented between SOPS + age and Sealed Secrets.
- [x] #2 No plaintext secrets are committed.
- [ ] #3 GitOps can deploy at least one test secret from the chosen mechanism.
- [x] #4 README documents key creation, local operator workflow, recovery expectations, and what must not be committed.
- [x] #5 make test or a new local validation target checks secret manifests for plaintext placeholder mistakes.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented initial secret bootstrap around Bitnami Sealed Secrets because the current Argo CD setup syncs plain manifests/Helm charts and would need extra repo-server customization for SOPS decryption. Added a pinned Sealed Secrets Argo CD child Application, a secret-smoke namespace, README workflow for kubeseal/cert fetch/key backup/recovery, and a GitOps secret scanner wired into make test. Remaining live verification: after Argo CD syncs the controller, generate a cluster-specific secret-smoke SealedSecret with kubeseal, commit it, sync, and confirm the decrypted Kubernetes Secret exists in the secret-smoke namespace.

Added Sealed Secrets key restore support. make sealed-secrets-backup saves the controller key, make sealed-secrets-restore reapplies it, and make argocd now performs an optional restore before applying the GitOps root so from-scratch clusters reuse the same sealing key when a backup is present. SEALED_SECRETS_BACKUP_FILE can point at an external encrypted/offline backup location when .state is cleaned.
<!-- SECTION:NOTES:END -->
