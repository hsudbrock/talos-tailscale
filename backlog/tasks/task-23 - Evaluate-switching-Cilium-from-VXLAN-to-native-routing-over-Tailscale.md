---
id: TASK-23
title: Evaluate switching Cilium from VXLAN to native routing over Tailscale
status: To Do
assignee:
  - '@Codex'
created_date: '2026-04-28 21:03'
labels:
  - networking
  - cilium
  - tailscale
  - routing
dependencies: []
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Assess whether this Talos-over-Tailscale cluster can safely move from Cilium VXLAN tunnel mode to Cilium native routing. The evaluation must focus on whether per-node PodCIDR routes can be installed and used over the nodes' Tailscale underlay, what changes would be required in Talos/Cilium configuration, and whether the operational tradeoff is favorable for this repo. Do not assume viability from node-to-node Tailscale reachability alone; prove or disprove end-to-end PodCIDR routing behavior.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The current VXLAN-based design and the expected native-routing packet path over Tailscale are documented, including why pods do not need Tailscale addresses.
- [ ] #2 A concrete routing design is proposed and tested for this topology, including how each node learns remote PodCIDRs and forwards them via remote nodes' Tailscale addresses.
- [ ] #3 A live evaluation proves or disproves that native routing works on this cluster, including bidirectional pod-to-pod connectivity across nodes without VXLAN encapsulation.
- [ ] #4 Compatibility is verified for NetworkPolicy enforcement, Hubble flow visibility, Metrics Server, Sealed Secrets, Longhorn, and the existing smoke workloads in the evaluated mode or in a documented test environment.
- [ ] #5 Any required Cilium settings such as routingMode, ipv4-native-routing-cidr, auto-direct-node-routes, masquerading behavior, or route-distribution requirements are documented with repo-specific recommendations.
- [ ] #6 Rollback steps back to VXLAN are documented and tested.
- [ ] #7 If the evaluation is positive, the repo changes needed to switch from VXLAN to native routing are identified or implemented through the existing GitOps/bootstrap flow.
<!-- AC:END -->
