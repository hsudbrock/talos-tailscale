---
id: TASK-5
title: Choose and implement initial secret bootstrap
status: To Do
assignee:
  - Codex
created_date: '2026-04-19 07:18'
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
- [ ] #1 Decision is documented between SOPS + age and Sealed Secrets.
- [ ] #2 No plaintext secrets are committed.
- [ ] #3 GitOps can deploy at least one test secret from the chosen mechanism.
- [ ] #4 README documents key creation, local operator workflow, recovery expectations, and what must not be committed.
- [ ] #5 make test or a new local validation target checks secret manifests for plaintext placeholder mistakes.
<!-- AC:END -->
