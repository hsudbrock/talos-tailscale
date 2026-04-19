---
id: TASK-10
title: Fix Talos 1.12 apply failure on existing static hostnames
status: Done
assignee: []
created_date: '2026-04-19 18:13'
updated_date: '2026-04-19 18:27'
labels:
  - talos
  - bug
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
make apply failed after switching .env to Talos v1.12.5 because Talos 1.12 generated configs include a HostnameConfig document with auto: stable, while the repo's per-node patch also added the legacy machine.network.hostname field. talosctl validate and talosctl apply-config reject that duplicate hostname model with: static hostname is already set in v1alpha1 config. Since Talos 1.12 is now the project minimum, generated configs should set static names through HostnameConfig only.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Talos 1.12 generated node configs validate locally with talosctl validate.
- [x] #2 Generated node configs set the static node name through HostnameConfig instead of legacy machine.network.hostname.
- [x] #3 make apply succeeds on freshly cleaned disks with Talos 1.12 configs.
- [x] #4 Local script tests cover HostnameConfig generation.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Clean-disk reproduction showed the failure is not stale VM disk state. Talos v1.12 generated configs include a HostnameConfig document with auto: stable, and the repo's node patch also adds legacy machine.network.hostname, causing local talosctl validate and first apply to fail.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed scripts/generate-configs.sh for the Talos 1.12+ hostname model. Node configs now patch only the Tailscale extension resource, then replace the generated HostnameConfig auto: stable value with hostname: <node>. This removes the invalid combination of HostnameConfig plus legacy machine.network.hostname. Regenerated configs validate with talosctl validate, and make apply succeeds after make clean-disks and make start. Updated script behavior tests to model HostnameConfig and the active Talos version.
<!-- SECTION:FINAL_SUMMARY:END -->
