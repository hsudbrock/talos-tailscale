---
id: TASK-13
title: Support unique node name suffixes for rebuilt clusters
status: Done
assignee: []
created_date: '2026-04-22 16:09'
updated_date: '2026-04-22 16:12'
labels:
  - tailscale
  - dns
  - bootstrap
  - ux
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add support for appending a configurable suffix to generated Talos node names so rebuilt clusters can avoid stale MagicDNS collisions in Tailscale. Support a random suffix mode suitable for from-scratch rebuilds, and make the from-scratch bootstrap flow refresh that suffix automatically.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Node names can be derived from the configured base names plus an optional suffix.
- [ ] #2 A random suffix mode generates a stable suffix for one cluster generation and uses it consistently across generated configs.
- [ ] #3 bootstrap-from-scratch refreshes the random suffix before regenerating configs.
- [ ] #4 README/env docs and local tests cover suffix behavior.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented NODE_NAME_SUFFIX support in scripts/lib.sh. Literal suffixes are appended to all node names, and NODE_NAME_SUFFIX=random now creates a stable per-generation suffix stored in .state/node-name-suffix. bootstrap-from-scratch removes that file before regenerating configs so rebuilt clusters get fresh unique names. Updated local .env, env example, README, and script behavior tests; bash tests pass.
<!-- SECTION:NOTES:END -->
