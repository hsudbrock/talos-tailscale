---
id: TASK-12
title: Add one-shot from-scratch cluster bootstrap target
status: Done
assignee: []
created_date: '2026-04-22 15:56'
updated_date: '2026-04-22 15:57'
labels:
  - make
  - bootstrap
  - automation
  - talos
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a make target that rebuilds the local cluster from scratch by clearing VM disks, starting the VMs, waiting until Talos APIs are ready for config application, applying configs, and bootstrapping Kubernetes. The target should orchestrate the existing scripts without requiring manual sleeps between steps.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A new make target performs clean-disks, start, readiness wait, apply, and bootstrap in sequence.
- [ ] #2 The new flow waits for Talos API readiness before applying configs instead of racing VM boot.
- [ ] #3 README/help text documents the new target and intended use.
- [ ] #4 Local script behavior tests cover the new target or script orchestration.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented scripts/wait-talos-apis.sh and scripts/bootstrap-from-scratch.sh. apply-configs.sh now waits for all localhost Talos API forwards before applying configs, and Makefile/README expose make bootstrap-from-scratch for the full clean-disks -> start -> wait -> apply -> bootstrap flow. Local shell and script behavior tests pass.
<!-- SECTION:NOTES:END -->
