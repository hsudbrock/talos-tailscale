---
id: TASK-25
title: Replace hosted Tailscale control plane with a local Headscale VM
status: To Do
assignee:
  - '@Codex'
created_date: '2026-04-29 16:43'
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
