---
id: TASK-11
title: Set default endpoints and nodes in generated talosconfig
status: To Do
assignee: []
created_date: '2026-04-22 15:55'
labels:
  - talos
  - ux
  - tooling
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The generated .state/talos/generated/talosconfig does not include default endpoints or nodes. As a result, plain talosctl commands fail unless --endpoints and --nodes are provided explicitly. Add a follow-up improvement so bootstrap or config generation writes sensible defaults into the generated talosconfig for the local cluster workflow.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Generated talosconfig contains a default control-plane endpoint suitable for local cluster administration.
- [ ] #2 Generated talosconfig contains a default node target or otherwise supports plain talosctl commands without repeated --nodes usage.
- [ ] #3 README documents the expected talosctl usage after the change.
- [ ] #4 Local tests cover the talosconfig defaults behavior.
<!-- AC:END -->
