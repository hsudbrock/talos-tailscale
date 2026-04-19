---
id: TASK-3
title: Prepare Talos nodes for Longhorn
status: To Do
assignee:
  - Codex
created_date: '2026-04-19 07:18'
labels:
  - talos
  - longhorn
  - storage
  - bootstrap
dependencies: []
documentation:
  - >-
    https://longhorn.io/docs/1.11.0/advanced-resources/os-distro-specific/talos-linux-support
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Update the Talos image/config generation path so worker nodes can run Longhorn safely on Talos.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Talos image schematic includes required Longhorn system extensions: siderolabs/iscsi-tools and siderolabs/util-linux-tools.
- [ ] #2 Generated Talos configs include any required Longhorn host mounts or Talos v1.11-compatible user volume configuration needed for Longhorn data.
- [ ] #3 Longhorn namespace pod security requirements are documented.
- [ ] #4 make test covers the generated image schematic/config changes.
- [ ] #5 README documents that make image, make configs, and machine config reapply are required before installing Longhorn.
<!-- AC:END -->
