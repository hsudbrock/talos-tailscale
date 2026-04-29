---
id: TASK-25.1
title: Design Headscale bootstrap architecture for the local Talos lab
status: Done
assignee:
  - '@Codex'
created_date: '2026-04-29 16:45'
updated_date: '2026-04-29 17:16'
labels:
  - networking
  - tailscale
  - headscale
  - design
  - talos
dependencies: []
parent_task_id: TASK-25
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Define how a locally hosted Headscale control plane should be introduced into this Talos-over-Tailscale lab before any node has joined the tailnet. The task should select the first-boot reachability model, the node-auth strategy, and the persistence/identity assumptions that later implementation tasks will depend on.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A bootstrap reachability design is selected for how Talos nodes contact Headscale before the tailnet exists, with tradeoffs documented.
- [x] #2 The authentication model is selected and documented, including whether to use reusable preauth keys, ephemeral keys, users/namespaces, and how rebuilds affect node identity.
- [x] #3 The resulting architecture is explicit about which traffic uses pre-tailnet paths versus post-tailnet paths.
- [x] #4 The parent task is updated with the accepted design constraints needed for implementation.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Inspect the current VM and cluster bootstrap flow in scripts/, config/, and README.md to identify where a Headscale VM and Tailscale enrollment fit.
2. Evaluate bootstrap reachability options for Talos nodes contacting Headscale before the tailnet exists, using the existing local VM networking as the baseline.
3. Select and document the architecture for first-boot reachability, authentication, and node identity persistence/rebuild behavior, including a clear split between pre-tailnet and post-tailnet traffic.
4. Update TASK-25.1 with the approved design notes and update parent TASK-25 with the implementation constraints and sequencing that downstream subtasks must follow.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Design decision: keep the existing QEMU user-mode networking model. The repo currently starts every Talos VM on its own isolated slirp network with only outbound Internet access plus host-local TCP forwards for the Talos API and Kubernetes API. There is no shared guest bridge today, so adding Headscale must not assume direct VM-to-VM reachability before the tailnet exists.

Selected bootstrap reachability model: provision Headscale as an additional local VM and expose its control-plane port back to the host with explicit QEMU host forwards. Talos nodes will reach Headscale through the guest-visible host gateway address on their slirp network (`10.0.2.2` per QEMU user-mode networking) plus a dedicated forwarded port. This keeps the current no-bridge VM design intact and avoids a larger networking refactor in the Headscale migration.

Selected authentication model: use non-interactive Headscale preauth keys rather than interactive registration or OIDC. The current harness already injects one shared `TS_AUTHKEY` into every node's `ExtensionServiceConfig`, so the minimal compatible Headscale design is a reusable automation-oriented preauth key. Use a tagged-device key for infrastructure ownership (for example `tag:talos`) rather than a human login flow. Headscale's defaults are one-use and one-hour validity, so downstream implementation must deliberately create a reusable key and document its rotation/expiration policy.

Ephemeral-vs-persistent decision: do not depend on ephemeral node enrollment for the first implementation. Instead, keep the existing node naming strategy (`NODE_NAME_SUFFIX`, including `random`) as the rebuild-collision control, and treat from-scratch Talos rebuilds as new node registrations whenever VM disks are wiped. This avoids coupling the design to Headscale ephemeral-node semantics while still preventing stale-name collisions in local testing.

Traffic split: before a node joins the tailnet, Talos bootstrap traffic and Headscale coordination traffic use only localhost host-forwards and the guest-to-host slirp gateway path. After enrollment, Talos API, etcd peer traffic, kubelet InternalIP selection, and Kubernetes east-west communication continue to prefer Tailscale addresses exactly as they do today. Headscale coordination traffic does not need to move onto the tailnet in this design; it can remain on the host-mediated path permanently.

DERP decision: do not make embedded DERP part of the initial Headscale migration. Headscale supports an embedded DERP server, but the current lab already relies on heavily NATed per-VM user-mode networking where relays may matter. The lower-risk first step is to migrate only the control server to Headscale while continuing to use the default public DERP map that Headscale serves unless explicitly overridden. A fully self-hosted DERP path can be evaluated later as separate scope.

TLS/URL constraint: use a Headscale server URL that is reachable from Talos nodes through the host-mediated bootstrap path. Because the current harness is unprivileged and does not have an existing certificate-distribution path into the Tailscale extension trust store, the implementation should avoid assuming a production-style public-HTTPS-on-443 deployment. If HTTPS is desired later, it will need an explicit certificate trust/bootstrap plan; otherwise a documented local-only HTTP or high-port HTTPS path is the pragmatic initial contract.

Parent-task implementation constraints: `scripts/start-vms.sh` / `lib.sh` will need a fourth VM definition with explicit forwarded ports for Headscale; `scripts/bootstrap-from-scratch.sh` must stop deleting all VM disks indiscriminately once the Headscale VM has persistent state; `.env`/config generation must grow explicit Headscale URL and auth-key inputs instead of the hosted-Tailscale-only `TS_AUTHKEY`; and validation/docs must distinguish Talos node rebuilds from Headscale state resets.

Additional user constraint: the local Headscale VM is an intermediate test environment only. The design target is that Headscale may later move to a remote/cloud VM (for example Hetzner, AWS, or Azure) without requiring a second redesign of Talos enrollment.

Portability refinement: downstream implementation must treat the Headscale control endpoint as an explicit configurable service URL rather than an implicit property of local QEMU networking. The host-mediated `10.0.2.2` plus forwarded-port path is a local development bootstrap mechanism, not the long-term architecture contract.

Portability refinement: avoid coupling config generation, docs, or validation to the assumption that Headscale runs on the same host as the Talos VMs. The local VM path should exercise the same logical enrollment interface that a future remote deployment will expose.

Portability refinement: TLS and trust decisions in the first implementation should preserve a migration path to a real remote endpoint. If the local test setup uses an expedient local-only transport mode, document it as a development-only exception rather than the durable interface.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Documented the Headscale bootstrap architecture for this lab without changing the existing isolated-QEMU networking model. The chosen design keeps Talos VMs on separate slirp networks, provisions Headscale as an additional VM, and exposes the Headscale control endpoint back through host-mediated port forwards so Talos nodes can reach it through the guest-visible host gateway before any tailnet exists.

Selected reusable non-interactive Headscale preauth keys as the initial enrollment model, with tagged infrastructure devices preferred over interactive or OIDC-based registration. Explicitly chose not to depend on ephemeral-node semantics in the first implementation; instead the existing node-name suffix strategy remains the rebuild-collision mechanism and Talos rebuilds are treated as fresh registrations when VM disks are wiped.

Captured the pre-tailnet versus post-tailnet traffic split, deferred embedded DERP from the first migration step, and recorded downstream implementation constraints on VM provisioning, persistent Headscale state, config inputs, and rebuild semantics in both TASK-25.1 and parent TASK-25.

Tests run: none. This subtask is design/documentation work in Backlog only; no repository code or runtime behavior was changed.
<!-- SECTION:FINAL_SUMMARY:END -->
