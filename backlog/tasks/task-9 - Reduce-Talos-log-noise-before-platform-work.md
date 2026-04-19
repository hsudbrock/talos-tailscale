---
id: TASK-9
title: Reduce Talos log noise before platform work
status: To Do
assignee:
  - Codex
created_date: '2026-04-19 07:22'
labels:
  - talos
  - logs
  - observability
  - cleanup
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Investigate and reduce recurring or avoidable Talos/Kubernetes log errors so genuine future failures are easier to spot before adding Longhorn, secrets, and SSO components.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A log audit command or script summarizes current warning/error patterns across Talos services without dumping full noisy logs.
- [ ] #2 The audit distinguishes historical boot/convergence noise from currently recurring errors.
- [ ] #3 Any actionable recurring errors are fixed or documented with rationale if they are expected and harmless.
- [ ] #4 Existing validation confirms the cluster remains healthy after any changes.
- [ ] #5 README documents the clean-log check and known acceptable transient messages.
<!-- AC:END -->
