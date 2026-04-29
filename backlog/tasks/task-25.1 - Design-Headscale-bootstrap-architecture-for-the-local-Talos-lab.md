---
id: TASK-25.1
title: Design Headscale bootstrap architecture for the local Talos lab
status: To Do
assignee:
  - '@Codex'
created_date: '2026-04-29 16:45'
labels:
  - networking
  - tailscale
  - headscale
  - design
  - talos
dependencies: []
parent_task_id: TASK-25
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Define how a locally hosted Headscale control plane should be introduced into this Talos-over-Tailscale lab before any node has joined the tailnet. The task should select the first-boot reachability model, the node-auth strategy, and the persistence/identity assumptions that later implementation tasks will depend on.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A bootstrap reachability design is selected for how Talos nodes contact Headscale before the tailnet exists, with tradeoffs documented.
- [ ] #2 The authentication model is selected and documented, including whether to use reusable preauth keys, ephemeral keys, users/namespaces, and how rebuilds affect node identity.
- [ ] #3 The resulting architecture is explicit about which traffic uses pre-tailnet paths versus post-tailnet paths.
- [ ] #4 The parent task is updated with the accepted design constraints needed for implementation.
<!-- AC:END -->
