---
id: TASK-17
title: Assign explicit QEMU UUIDs to Talos VMs
status: To Do
assignee: []
created_date: '2026-04-22 16:45'
labels: []
dependencies: []
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Talos dashboard appears to show all-zero UUID values for the QEMU-backed nodes. Add explicit per-node QEMU UUID assignment so inventory fields are stable and easier to interpret.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each VM is started with a stable explicit QEMU UUID instead of relying on an all-zero default
- [ ] #2 Talos/Kubernetes surfaces non-zero machine or system UUID values that are distinct per node
- [ ] #3 README documents the UUID behavior and any limitations of the dashboard field
<!-- AC:END -->
