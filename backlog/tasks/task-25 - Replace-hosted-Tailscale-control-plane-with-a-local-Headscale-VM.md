---
id: TASK-25
title: Replace hosted Tailscale control plane with a local Headscale VM
status: To Do
assignee:
  - '@Codex'
created_date: '2026-04-29 16:43'
updated_date: '2026-04-29 17:17'
labels:
  - networking
  - tailscale
  - headscale
  - vm
  - talos
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Migrate this local Talos-over-Tailscale environment away from the hosted Tailscale control plane and onto a Headscale server that runs as an additional local VM alongside the Talos nodes. The goal is to keep the cluster's Tailscale-based node-to-node connectivity model while making control-plane ownership local to this lab environment. The work must cover Headscale VM lifecycle, Talos node enrollment, bootstrap sequencing, and operational validation for the existing platform components.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A concrete architecture is selected and documented for running Headscale as an additional local VM, including how it is network-reachable during first boot and how Talos nodes discover and authenticate to it.
- [ ] #2 The repo can provision and manage the Headscale VM alongside the Talos VMs, with pinned images or install steps and documented local state requirements.
- [ ] #3 Talos node bootstrap is updated so ext-tailscale joins the local Headscale control plane instead of the hosted Tailscale service, without requiring manual per-node rework after every rebuild.
- [ ] #4 Cluster validation proves that all Talos nodes join the Headscale-managed tailnet, receive the expected node identities, and can still reach each other over their selected Tailscale/InternalIP addresses.
- [ ] #5 Compatibility is verified for Kubernetes bootstrap, Cilium, Argo CD, Metrics Server, Sealed Secrets, Longhorn, and the existing smoke workloads after the Headscale migration or in a documented evaluation environment.
- [ ] #6 Secrets, auth keys, preauth keys, or OIDC/user-auth implications introduced by Headscale are documented, including which values belong in .env versus external secret storage.
- [ ] #7 README guidance covers initial Headscale bring-up, rebuild workflow, validation, and troubleshooting for the local-control-plane design.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Finalize the bootstrap architecture in TASK-25.1, including pre-tailnet reachability, Headscale authentication, and rebuild/identity constraints.
2. Provision a dedicated Headscale VM alongside the Talos VMs with pinned installation inputs and explicit local state handling in TASK-25.2.
3. Repoint Talos ext-tailscale bootstrap and configuration generation to the local Headscale control plane in TASK-25.3.
4. Document bring-up, rebuild, validation, and secret-handling workflows in TASK-25.4.
5. Validate Talos, Kubernetes bootstrap, and platform components on Headscale-managed node networking in TASK-25.5.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Accepted architecture constraints from TASK-25.1: keep the existing isolated-QEMU/slirp topology and bootstrap Headscale via host-mediated port forwards rather than introducing a shared guest bridge. Talos nodes will contact Headscale through the guest-visible host gateway path during first boot.

Accepted auth constraints from TASK-25.1: initial implementation uses reusable non-interactive Headscale preauth keys, ideally for tagged infrastructure devices, and continues to rely on the repo's node-name suffix handling to avoid rebuild collisions. Do not make OIDC, interactive registration, or ephemeral-node semantics part of the first migration step.

Accepted networking constraints from TASK-25.1: post-enrollment Talos/Kubernetes traffic still prefers Tailscale/InternalIP paths exactly as today, while Headscale coordination traffic may remain on the host-mediated path. Embedded DERP is explicitly out of scope for the first migration; keep the default external DERP map unless a later task chooses to self-host relay infrastructure too.

Accepted implementation constraints from TASK-25.1: downstream subtasks must preserve persistent Headscale VM state across ordinary Talos rebuilds, introduce explicit Headscale URL/port/auth configuration in `.env` and generated configs, and update validation/documentation to distinguish node rebuilds from full Headscale resets.

Additional user constraint accepted after TASK-25.1: the local Headscale VM is only an intermediate validation environment. The durable architecture should allow Headscale to move later to a remote/cloud VM with minimal changes to Talos enrollment and cluster operations.

Updated implementation constraint: treat `HEADSCALE_URL` (or equivalent control endpoint input) as a first-class configuration value and keep the host-mediated local VM path as a development mode, not as a hardcoded architectural assumption.

Updated portability constraint: TASK-25.2 and TASK-25.3 should shape provisioning and config generation so the local VM exercises the same enrollment contract a future remote Headscale service will use. Avoid repo assumptions that Headscale is co-located on the QEMU host indefinitely.
<!-- SECTION:NOTES:END -->
