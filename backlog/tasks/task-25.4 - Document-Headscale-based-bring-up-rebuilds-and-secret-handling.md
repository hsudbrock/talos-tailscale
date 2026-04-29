---
id: TASK-25.4
title: 'Document Headscale-based bring-up, rebuilds, and secret handling'
status: To Do
assignee:
  - '@Codex'
created_date: '2026-04-29 16:45'
labels:
  - networking
  - tailscale
  - headscale
  - docs
  - operations
dependencies: []
parent_task_id: TASK-25
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Document how operators bring up, rebuild, and troubleshoot this lab once Headscale becomes the local Tailscale control plane. The documentation should cover both happy-path operations and the new secret/auth material introduced by Headscale.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 README guidance covers the order of operations for starting Headscale and then bootstrapping the Talos cluster.
- [ ] #2 Documentation explains which Headscale-related values belong in .env, which should stay external, and how to rotate or recreate them during rebuilds.
- [ ] #3 Troubleshooting notes cover at least bootstrap reachability, node enrollment, and post-join connectivity issues.
- [ ] #4 The documented workflow is consistent with the implemented automation and validation commands.
<!-- AC:END -->
