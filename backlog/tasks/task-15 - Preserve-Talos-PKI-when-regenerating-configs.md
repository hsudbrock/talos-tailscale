---
id: TASK-15
title: Preserve Talos PKI when regenerating configs
status: To Do
assignee: []
created_date: '2026-04-22 16:42'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Today make configs regenerates Talos PKI and overwrites the generated talosconfig, which prevents live config rollouts to an existing cluster. Add a workflow that reuses existing cluster secrets so machine configs can be refreshed without recreating the cluster.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Config regeneration can reuse existing Talos cluster secrets instead of always generating new PKI
- [ ] #2 Operators can regenerate machine configs for a running cluster without invalidating the existing talosconfig
- [ ] #3 README documents the safe workflow for config-only changes on an existing cluster
<!-- AC:END -->
