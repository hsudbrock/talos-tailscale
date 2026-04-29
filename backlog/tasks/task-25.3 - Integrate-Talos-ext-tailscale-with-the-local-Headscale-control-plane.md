---
id: TASK-25.3
title: Integrate Talos ext-tailscale with the local Headscale control plane
status: To Do
assignee:
  - '@Codex'
created_date: '2026-04-29 16:45'
labels:
  - networking
  - tailscale
  - headscale
  - talos
  - integration
dependencies: []
parent_task_id: TASK-25
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Update Talos bootstrap and generated node configuration so ext-tailscale joins the local Headscale control plane instead of the hosted Tailscale service. The integration should be rebuild-friendly and avoid manual per-node edits after every cluster recreation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Generated Talos configuration points ext-tailscale at Headscale using the selected bootstrap-reachable endpoint.
- [ ] #2 Required auth material is injected through the repo workflow without hardcoding secrets into tracked files.
- [ ] #3 A from-scratch node bootstrap joins all Talos nodes to the Headscale-managed tailnet without manual per-node repair.
- [ ] #4 The old hosted-Tailscale dependency is removed or clearly isolated behind configuration switches if temporary fallback is retained.
<!-- AC:END -->
