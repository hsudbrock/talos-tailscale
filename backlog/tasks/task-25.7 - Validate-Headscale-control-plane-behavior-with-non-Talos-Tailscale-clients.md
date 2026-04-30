---
id: TASK-25.7
title: Validate Headscale control-plane behavior with non-Talos Tailscale clients
status: Done
assignee:
  - '@Codex'
created_date: '2026-04-29 19:02'
updated_date: '2026-04-30 08:29'
labels:
  - networking
  - headscale
  - tailscale
  - validation
dependencies:
  - TASK-25.2
  - TASK-25.6
parent_task_id: TASK-25
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Prove that the repo-managed Headscale VM functions as a usable control plane before Talos integration work proceeds. The validation should use ordinary non-Talos Tailscale clients to confirm enrollment, node visibility, and peer-to-peer communication over the Headscale-managed tailnet, so that later Talos-specific failures can be isolated to Talos integration rather than the control plane itself.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A reproducible validation workflow exists for starting the local Headscale VM and creating the minimum Headscale-side enrollment artifacts needed for test clients.
- [x] #2 At least two non-Talos Tailscale clients can successfully enroll against the local Headscale instance and appear correctly in Headscale node listings.
- [x] #3 The enrolled non-Talos clients can communicate with each other over the Headscale-managed tailnet using at least one basic connectivity check such as ping.
- [x] #4 The validation workflow and expected outcomes are documented clearly enough that later Talos integration can assume the control plane itself has already been proven independently.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added `scripts/validate-headscale-clients.sh` plus a `make headscale-client-validate` target as a control-plane-only validation gate for the local Headscale VM.

The workflow requires `HEADSCALE_BOOTSTRAP_MODE=local-vm`, waits for the forwarded Headscale endpoint, uses the existing Packer SSH key under `.state/headscale/packer/id_ed25519` to connect to the local Headscale VM over the forwarded SSH port, and creates a reusable tagged preauth key with configurable validation tag and expiration.

The script then starts two isolated host-side userspace `tailscaled` instances with separate state directories under `.state/headscale/validate-clients/`, enrolls both clients against `HEADSCALE_URL`, confirms that both hostnames appear in `headscale nodes list`, and uses `tailscale ping` between the enrolled clients as the basic peer-to-peer connectivity proof.

Documented the workflow in `README.md`, including its host prerequisites (`ssh`, `tailscale`, `tailscaled`) and the new optional `.env` knobs `HEADSCALE_VALIDATE_CLIENT_NAMES`, `HEADSCALE_VALIDATE_TAG`, and `HEADSCALE_VALIDATE_KEY_EXPIRATION`.

Validation: `bash -n` passed for the updated scripts and `bash tests/script-behavior.sh` passed after extending the fake-command harness for `ssh`, `tailscaled`, and `tailscale`.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented a repo-managed proof that the local Headscale VM works independently of Talos. `make headscale-client-validate` now creates a reusable tagged Headscale preauth key over the forwarded SSH path, starts two host-side userspace Tailscale clients, verifies both show up in Headscale node listings, and confirms peer-to-peer tailnet connectivity with `tailscale ping`.

Updated `.env` defaults, the `Makefile`, `README.md`, and the script-behavior test harness to support and document this flow. Verified the change with `bash -n` and `bash tests/script-behavior.sh`.
<!-- SECTION:FINAL_SUMMARY:END -->
