---
id: TASK-4.1
title: Add secondary worker data disk for Longhorn
status: Done
assignee:
  - '@Codex'
created_date: '2026-04-22 21:05'
updated_date: '2026-04-22 21:07'
labels:
  - talos
  - longhorn
  - storage
  - qemu
dependencies:
  - TASK-3
parent_task_id: TASK-4
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Attach a second virtual disk to worker VMs so Longhorn can use dedicated Talos user-volume capacity without competing with the Talos install disk.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Worker VMs get a second virtual data disk while control planes keep the existing single-disk layout.
- [x] #2 The default Longhorn disk selector targets the worker data disk instead of any virtio disk.
- [x] #3 Local tests cover the extra worker disk creation and QEMU launch arguments.
- [x] #4 README and env examples document the worker data disk sizing and how it relates to Longhorn.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Updated QEMU worker startup to create and attach a second virtio qcow2 disk per worker while leaving control-plane nodes on the existing single install disk. Added WORKER_DATA_DISK_GIB as a configurable default and switched the Longhorn UserVolumeConfig selector to disk.dev_path == "/dev/vdb" so Longhorn targets the dedicated worker data disk.

Extended the shell tests to verify worker-only data disk creation, QEMU launch arguments, and the updated Longhorn disk selector. Documented the new worker data disk behavior and env knobs in the README and env example. Verified with make test.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added dedicated worker data disks for Longhorn. Worker VMs now attach a second virtio qcow2 disk by default, the Longhorn Talos user volume selector targets /dev/vdb, and the repo documents/tests the new layout. Verified with make test.
<!-- SECTION:FINAL_SUMMARY:END -->
