---
id: TASK-16
title: Remove PodSecurity warnings from make validate
status: Done
assignee: []
created_date: '2026-04-22 16:42'
updated_date: '2026-04-22 16:55'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The current make validate output includes PodSecurity warnings for the temporary tailnet-curl pod. Update the validation probe so it remains useful without emitting avoidable policy violations.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The temporary validation curl pod complies with the cluster PodSecurity policy
- [x] #2 make validate succeeds without PodSecurity violation warnings in normal output
- [x] #3 Behavior tests and README reflect the updated validation approach
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Replaced the temporary kubectl run probe with a PodSecurity-compliant one-shot pod manifest. The pod now sets RuntimeDefault seccomp, drops all capabilities, disables privilege escalation, and runs as explicit non-root UID/GID 65532. Validation waits for phase=Succeeded, prints pod logs, and deletes the pod afterward.
Verified with bash tests/script-behavior.sh and a live timeout 300s make validate run on 2026-04-22. The validation output no longer emits PodSecurity warnings.
<!-- SECTION:NOTES:END -->
