---
id: TASK-25.3
title: Integrate Talos ext-tailscale with the local Headscale control plane
status: Done
assignee:
  - '@Codex'
created_date: '2026-04-29 16:45'
updated_date: '2026-04-30 17:36'
labels:
  - networking
  - tailscale
  - headscale
  - talos
  - integration
dependencies: []
parent_task_id: TASK-25
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Update Talos bootstrap and generated node configuration so ext-tailscale joins the local Headscale control plane instead of the hosted Tailscale service. The integration should be rebuild-friendly and avoid manual per-node edits after every cluster recreation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Generated Talos configuration points ext-tailscale at Headscale using the selected bootstrap-reachable endpoint.
- [x] #2 Required auth material is injected through the repo workflow without hardcoding secrets into tracked files.
- [x] #3 A from-scratch node bootstrap joins all Talos nodes to the Headscale-managed tailnet without manual per-node repair.
- [x] #4 The old hosted-Tailscale dependency is removed or clearly isolated behind configuration switches if temporary fallback is retained.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
`scripts/generate-configs.sh` now treats hosted Tailscale and Headscale as separate bootstrap modes. In `HEADSCALE_BOOTSTRAP_MODE=disabled`, it preserves the old `TS_AUTHKEY` path. In `local-vm` and `external` modes, it requires `HEADSCALE_URL` and resolves Talos-node auth through a dedicated Headscale path instead of reusing the hosted-Tailscale-only workflow.

Added `scripts/ensure-headscale-auth-key.sh` to provision Talos enrollment auth for Headscale. For `local-vm`, it starts/waits for the Headscale support VM, connects over the forwarded SSH port with the existing Packer key, ensures a dedicated `headscale-talos` user exists, creates a reusable tagged preauth key, stores it in `.state/headscale/talos-authkey`, and prints only the key so config generation can inject it into `ExtensionServiceConfig`. For `external`, the workflow expects an explicit `HEADSCALE_AUTH_KEY` in the environment.

Generated Talos configs now inject both `TS_AUTHKEY=<headscale key>` and `TS_EXTRA_ARGS=--login-server=${HEADSCALE_URL} --reset`, so `ext-tailscale` points at Headscale instead of the hosted Tailscale control plane while preserving the existing per-node hostname and DNS settings.

`scripts/apply-configs.sh` now retries authenticated config application when the first control-plane node is transitioning from insecure first boot into its real Talos identity. This fixed a real `authentication handshake failed: EOF` failure during from-scratch Headscale bootstrap.

Validation:
- `bash tests/script-behavior.sh`
- `make --no-print-directory bootstrap-from-scratch`
- `ssh -i .state/headscale/packer/id_ed25519 -p 10022 packer@127.0.0.1 'sudo headscale nodes list'`
- `talosctl --talosconfig .state/talos/generated/talosconfig --endpoints 127.0.0.1:50001 --nodes 127.0.0.1 service ext-tailscale` on the control-plane nodes
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Talos `ext-tailscale` is now integrated with the local Headscale control plane. Generated configs in Headscale mode no longer depend on the hosted-Tailscale-only `TS_AUTHKEY` path; instead they inject a Headscale-issued reusable auth key and a `--login-server=${HEADSCALE_URL}` override so Talos nodes join Headscale directly during bootstrap.

For the local-vm workflow, the repo now provisions Talos enrollment auth automatically by starting/waiting for the Headscale VM, ensuring a dedicated `headscale-talos` user, and creating a reusable tagged preauth key stored under `.state/headscale/talos-authkey`. A real `make bootstrap-from-scratch` run then brought up fresh Talos nodes that appeared in `headscale nodes list` with `100.64.0.x` addresses, confirming end-to-end Headscale enrollment without manual per-node repair.
<!-- SECTION:FINAL_SUMMARY:END -->
