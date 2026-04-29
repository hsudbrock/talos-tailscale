---
id: TASK-25.5
title: Validate cluster and platform behavior on Headscale-managed node networking
status: To Do
assignee:
  - '@Codex'
created_date: '2026-04-29 16:45'
labels:
  - networking
  - tailscale
  - headscale
  - validation
  - cilium
dependencies: []
parent_task_id: TASK-25
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Prove that the cluster still boots and the platform still functions after Talos nodes move from the hosted Tailscale control plane to the local Headscale VM. This task is the compatibility gate for accepting the migration.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Validation proves every Talos node joins Headscale and retains the expected node-to-node connectivity over the chosen Tailscale/InternalIP addresses.
- [ ] #2 Kubernetes bootstrap, Cilium, and the repo\'s base smoke validation succeed on the Headscale-backed cluster.
- [ ] #3 Argo CD, Metrics Server, Sealed Secrets, Longhorn, and the existing smoke workloads are verified on the Headscale-backed cluster.
- [ ] #4 Any Headscale-specific failure modes discovered during validation are documented with concrete troubleshooting steps or follow-up tasks.
<!-- AC:END -->
