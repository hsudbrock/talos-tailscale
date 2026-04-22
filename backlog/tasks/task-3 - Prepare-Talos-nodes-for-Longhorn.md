---
id: TASK-3
title: Prepare Talos nodes for Longhorn
status: Done
assignee:
  - Codex
created_date: '2026-04-19 07:18'
updated_date: '2026-04-22 20:31'
labels:
  - talos
  - longhorn
  - storage
  - bootstrap
dependencies:
  - TASK-9
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
- [x] #1 Talos image schematic includes required Longhorn system extensions: siderolabs/iscsi-tools and siderolabs/util-linux-tools.
- [x] #2 Generated Talos configs include any required Longhorn host mounts or Talos v1.11-compatible user volume configuration needed for Longhorn data.
- [x] #3 Longhorn namespace pod security requirements are documented.
- [x] #4 make test covers the generated image schematic/config changes.
- [x] #5 README documents that make image, make configs, and machine config reapply are required before installing Longhorn.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Log cleanup should run before Longhorn preparation so storage and platform work starts from a quieter baseline.

Added Longhorn Talos prerequisites to the image/config generation flow. The Talos Image Factory schematic now includes siderolabs/iscsi-tools and siderolabs/util-linux-tools alongside tailscale.

Worker configs now get a dedicated kubelet bind mount for /var/mnt/longhorn plus an appended UserVolumeConfig named longhorn, with the disk selector configurable via LONGHORN_DISK_SELECTOR and defaulting to the repo's virtio QEMU disk.

Documented the required Longhorn data path and privileged Pod Security namespace label in the README and .env example. Verified with make test.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Prepared Talos nodes for Longhorn. The repo now bakes Longhorn's required system extensions into the Talos schematic, generates worker configs with the /var/mnt/longhorn bind mount plus a Talos UserVolumeConfig, exposes Longhorn disk selector defaults in .env, and documents the required Pod Security and reapply flow. Verified with make test.
<!-- SECTION:FINAL_SUMMARY:END -->
