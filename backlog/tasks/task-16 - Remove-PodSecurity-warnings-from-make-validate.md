---
id: TASK-16
title: Remove PodSecurity warnings from make validate
status: To Do
assignee: []
created_date: '2026-04-22 16:42'
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
- [ ] #1 The temporary validation curl pod complies with the cluster PodSecurity policy
- [ ] #2 make validate succeeds without PodSecurity violation warnings in normal output
- [ ] #3 Behavior tests and README reflect the updated validation approach
<!-- AC:END -->
