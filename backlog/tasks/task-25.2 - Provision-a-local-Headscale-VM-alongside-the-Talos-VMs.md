---
id: TASK-25.2
title: Provision a local Headscale VM alongside the Talos VMs
status: To Do
assignee:
  - '@Codex'
created_date: '2026-04-29 16:45'
labels:
  - networking
  - tailscale
  - headscale
  - vm
  - provisioning
dependencies: []
parent_task_id: TASK-25
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add repo-managed lifecycle support for a Headscale VM that runs alongside the Talos VMs. The outcome should be a repeatable way to start, stop, and persist the local Tailscale control plane needed by later integration work.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The repo can create and boot a dedicated Headscale VM with documented image or installation source choices.
- [ ] #2 Headscale state persistence requirements are defined and implemented so rebuilds do not accidentally wipe required control-plane state unless intended.
- [ ] #3 A readiness check proves the Headscale service is reachable through the selected bootstrap path before Talos node enrollment begins.
- [ ] #4 The local VM workflow is documented enough for follow-on Talos integration work to depend on it.
<!-- AC:END -->
