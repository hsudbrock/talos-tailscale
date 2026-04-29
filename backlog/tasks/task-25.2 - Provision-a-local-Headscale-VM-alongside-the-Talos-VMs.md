---
id: TASK-25.2
title: Provision a local Headscale VM alongside the Talos VMs
status: Done
assignee:
  - '@Codex'
created_date: '2026-04-29 16:45'
updated_date: '2026-04-29 17:26'
labels:
  - networking
  - tailscale
  - headscale
  - vm
  - provisioning
dependencies: []
parent_task_id: TASK-25
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add repo-managed lifecycle support for a Headscale VM that runs alongside the Talos VMs. The outcome should be a repeatable way to start, stop, and persist the local Tailscale control plane needed by later integration work.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The repo can create and boot a dedicated Headscale VM with documented image or installation source choices.
- [x] #2 Headscale state persistence requirements are defined and implemented so rebuilds do not accidentally wipe required control-plane state unless intended.
- [x] #3 A readiness check proves the Headscale service is reachable through the selected bootstrap path before Talos node enrollment begins.
- [x] #4 The local VM workflow is documented enough for follow-on Talos integration work to depend on it.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Extend the VM lifecycle layer in scripts/lib.sh, scripts/start-vms.sh, and scripts/stop-vms.sh so the repo can manage a dedicated Headscale VM without treating it as a Talos node.
2. Add explicit Headscale configuration inputs to .env and the example config, centered on a portable control endpoint such as HEADSCALE_URL, with the local VM/host-forward path documented as the development bootstrap mode.
3. Implement persistent local Headscale state handling so normal Talos rebuilds do not wipe the Headscale VM disk or its data unless explicitly requested.
4. Add a readiness check that proves the Headscale service is reachable through the configured bootstrap path before later node-enrollment work depends on it.
5. Update tests and README so the local VM workflow is reproducible and clearly positioned as an interim test target for a later remote/cloud Headscale deployment.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented a local Headscale support-VM lifecycle without adding the VM to the Talos node list. `scripts/lib.sh` now carries separate Headscale bootstrap settings, starts/stops the support VM independently, and defaults `HEADSCALE_URL` to the local guest-visible host-forward path only when `HEADSCALE_BOOTSTRAP_MODE=local-vm`.

Implemented persistent local state handling by giving Headscale its own qcow2 disk path outside the Talos node loop. `scripts/bootstrap-from-scratch.sh` now deletes only Talos node disks and preserves the Headscale disk unless the user explicitly runs `make clean` or `make clean-disks`.

Added `scripts/wait-headscale.sh` plus a `make headscale-wait` target. The real workflow defaults to a port-based reachability probe against the selected Headscale endpoint, while tests use a pidfile probe because the fake QEMU harness does not create real listeners.

Documented the local-vm versus external endpoint model in `.env` and `README.md`, including the portability constraint that `HEADSCALE_URL` is the first-class client endpoint and the local VM is only an interim test environment for a later remote/cloud deployment.

Validation: `bash -n` passed for the updated scripts, and `bash tests/script-behavior.sh` passed after extending the fake QEMU helpers and assertions for the new Headscale support-VM flow.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added repo-managed lifecycle support for a local Headscale support VM without coupling it to the Talos node list. The VM logic lives alongside the existing QEMU helpers, starts automatically in `HEADSCALE_BOOTSTRAP_MODE=local-vm`, and uses a separate persistent qcow2 disk so the local Headscale control plane survives ordinary Talos rebuilds.

Introduced portable Headscale configuration inputs in `.env` and the example config, centered on a first-class `HEADSCALE_URL` model. For local-vm mode the repo defaults that client endpoint to the guest-visible host-forward path through QEMU slirp, but the documentation and code now treat the local VM as an interim test mode rather than a permanent co-location assumption.

Added a readiness probe via `scripts/wait-headscale.sh` and `make headscale-wait`, updated `bootstrap-from-scratch` to preserve Headscale state while rebuilding only Talos node disks, and documented the workflow in `README.md`, including the recommended Debian/Ubuntu qcow2 guest preparation path for Headscale.

Tests run: `bash -n scripts/lib.sh scripts/prepare-image.sh scripts/generate-configs.sh scripts/start-vms.sh scripts/wait-headscale.sh scripts/apply-configs.sh scripts/bootstrap.sh scripts/bootstrap-from-scratch.sh scripts/bootstrap-argocd.sh scripts/validate.sh scripts/logs-audit.sh scripts/validate-gitops-secrets.sh scripts/backup-sealed-secrets-key.sh scripts/restore-sealed-secrets-key.sh scripts/stop-vms.sh`; `bash tests/script-behavior.sh`.
<!-- SECTION:FINAL_SUMMARY:END -->
