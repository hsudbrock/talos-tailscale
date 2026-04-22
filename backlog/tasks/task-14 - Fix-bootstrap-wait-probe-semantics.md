---
id: TASK-14
title: Fix bootstrap wait probe semantics
status: Done
assignee: []
created_date: '2026-04-22 16:22'
updated_date: '2026-04-22 16:30'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The generic wait script currently uses talosctl version as its readiness probe. That is too strict before apply-config and can stall bootstrap-from-scratch even when the VM is visibly ready in maintenance mode.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Pre-apply waits detect first-boot Talos maintenance availability without relying on talosctl version
- [x] #2 Post-apply flow remains bounded and does not wait forever
- [x] #3 Behavior tests cover the updated wait semantics
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Switched scripts/wait-talos-apis.sh to a bounded TCP port probe by default, with WAIT_TALOS_PROBE=version retained for behavior tests.
Unset derived endpoint/name variables in bootstrap-from-scratch after rotating the random suffix so the next generation does not inherit the previous CONTROL_PLANE_ENDPOINT.
Validated with bash tests/script-behavior.sh and a live timeout 900s make bootstrap-from-scratch run.
<!-- SECTION:NOTES:END -->
