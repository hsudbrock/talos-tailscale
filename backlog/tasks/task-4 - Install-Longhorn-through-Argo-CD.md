---
id: TASK-4
title: Install Longhorn through Argo CD
status: Done
assignee:
  - Codex
created_date: '2026-04-19 07:18'
updated_date: '2026-04-22 21:37'
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
- [x] #1 GitOps root includes a Longhorn child Application.
- [x] #2 Longhorn is installed from a pinned chart/version.
- [x] #3 Longhorn namespace/security labels are declared in Git.
- [x] #4 A default or named Longhorn StorageClass is created intentionally.
- [x] #5 Validation includes a PVC smoke test that binds, mounts, writes data, and cleans up.
- [x] #6 README documents install, status, and troubleshooting commands.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Installed Longhorn through the Argo CD root with a pinned chart version and privileged namespace labels.
Validated the default longhorn StorageClass and a live PVC smoke path that bound, mounted, wrote data, and cleaned up.
Added a GitOps-managed storage-smoke sample workload backed by a Longhorn PVC and verified it served persisted content in-cluster.
<!-- SECTION:FINAL_SUMMARY:END -->
