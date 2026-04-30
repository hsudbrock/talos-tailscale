---
id: TASK-25.8
title: Evaluate self-hosted DERP for the Headscale lab
status: To Do
assignee:
  - '@Codex'
created_date: '2026-04-30 08:49'
labels:
  - networking
  - headscale
  - tailscale
  - derp
  - evaluation
dependencies:
  - TASK-25.3
parent_task_id: TASK-25
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Evaluate whether this lab should continue using Tailscale's public DERP map after the Headscale migration or move to a self-hosted DERP path. The outcome should make the relay-network ownership tradeoff explicit and, if a self-hosted path is chosen, define the required Headscale, VM, port, and validation changes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The current dependency on Tailscale's public DERP servers is documented along with the practical reasons it was kept for the initial Headscale migration.
- [ ] #2 A self-hosted DERP option is evaluated for this lab, including required Headscale config, exposed ports, and expected impact on the QEMU/NAT topology.
- [ ] #3 The decision is recorded clearly as either "keep public DERP for now" or "implement self-hosted DERP", with rationale and follow-up implementation notes.
- [ ] #4 If self-hosted DERP is selected, concrete implementation and validation steps are captured in this task or split into follow-up tasks.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Review the current Headscale config and lab networking assumptions to capture exactly how DERP is being sourced today.
2. Evaluate the embedded/self-hosted DERP path against the current slirp-based local VM topology, including required listener ports and likely relay behavior.
3. Decide whether to keep the default public DERP map or move to a self-hosted DERP server for this lab.
4. Record the outcome and any required implementation follow-up under TASK-25.
<!-- SECTION:PLAN:END -->
