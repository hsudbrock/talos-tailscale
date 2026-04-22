---
id: TASK-4
title: Install Longhorn through Argo CD
status: In Progress
assignee:
  - Codex
created_date: '2026-04-19 07:18'
updated_date: '2026-04-22 21:12'
labels:
  - argocd
  - longhorn
  - storage
  - gitops
dependencies:
  - TASK-3
documentation:
  - 'https://longhorn.io/docs/latest/deploy/install/'
  - 'https://longhorn.io/docs/latest/nodes-and-volumes/volumes/rwx-volumes/'
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add Longhorn as the first GitOps-managed platform component and validate dynamic persistent storage.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 GitOps root includes a Longhorn child Application.
- [ ] #2 Longhorn is installed from a pinned chart/version.
- [ ] #3 Longhorn namespace/security labels are declared in Git.
- [ ] #4 A default or named Longhorn StorageClass is created intentionally.
- [ ] #5 Validation includes a PVC smoke test that binds, mounts, writes data, and cleans up.
- [ ] #6 README documents install, status, and troubleshooting commands.
<!-- AC:END -->
