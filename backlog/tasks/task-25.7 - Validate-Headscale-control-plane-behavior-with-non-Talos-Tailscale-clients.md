---
id: TASK-25.7
title: Validate Headscale control-plane behavior with non-Talos Tailscale clients
status: To Do
assignee:
  - '@Codex'
created_date: '2026-04-29 19:02'
labels:
  - networking
  - headscale
  - tailscale
  - validation
dependencies:
  - TASK-25.2
  - TASK-25.6
parent_task_id: TASK-25
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Prove that the repo-managed Headscale VM functions as a usable control plane before Talos integration work proceeds. The validation should use ordinary non-Talos Tailscale clients to confirm enrollment, node visibility, and peer-to-peer communication over the Headscale-managed tailnet, so that later Talos-specific failures can be isolated to Talos integration rather than the control plane itself.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A reproducible validation workflow exists for starting the local Headscale VM and creating the minimum Headscale-side enrollment artifacts needed for test clients.
- [ ] #2 At least two non-Talos Tailscale clients can successfully enroll against the local Headscale instance and appear correctly in Headscale node listings.
- [ ] #3 The enrolled non-Talos clients can communicate with each other over the Headscale-managed tailnet using at least one basic connectivity check such as ping.
- [ ] #4 The validation workflow and expected outcomes are documented clearly enough that later Talos integration can assume the control plane itself has already been proven independently.
<!-- AC:END -->
