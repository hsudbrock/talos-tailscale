---
id: TASK-24
title: Switch Cilium from kube-proxy mode to kube-proxy-free mode
status: To Do
assignee:
  - '@Codex'
created_date: '2026-04-28 21:05'
updated_date: '2026-04-28 21:05'
labels:
  - networking
  - cilium
  - kube-proxy
  - ebpf
  - tailscale
  - talos
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Evaluate migrating this Talos-over-Tailscale cluster from Cilium with kube-proxy enabled to Cilium's kube-proxy-free mode. The work must validate that Cilium can safely and fully replace kube-proxy in this topology, including control-plane reachability during bootstrap, Kubernetes Service behavior, and compatibility with the existing GitOps-managed platform components. This remains an evaluation-phase platform change: rebuild-based validation is acceptable, and the task does not require a tested rollback path on a running cluster.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A deployment design is selected and documented for kube-proxy-free Cilium in this repo, including bootstrap sequencing, required API server host/port settings, and any Talos-specific or multi-interface node-IP considerations.
- [ ] #2 The repo is updated so bootstrap and steady-state cluster config run Cilium in kube-proxy-free mode with pinned versions and documented rationale.
- [ ] #3 kube-proxy is removed or disabled in the evaluated cluster in a way that avoids ambiguous coexistence, and Cilium reports kube-proxy replacement enabled in live status output.
- [ ] #4 Live validation proves Kubernetes Service functionality for ClusterIP, NodePort or equivalent external exposure in this repo, DNS, and hostPort behavior if it is relied upon.
- [ ] #5 Compatibility is verified for Argo CD, Metrics Server, Sealed Secrets, Longhorn, Hubble, and the existing smoke workloads after the migration or in a documented evaluation environment.
- [ ] #6 The migration documents and accounts for known connection-disruption risk when switching from kube-proxy to Cilium replacement on an existing cluster, with either a rebuild strategy or explicit cutover steps.
- [ ] #7 README validation and troubleshooting guidance is updated for kube-proxy-free operation.
<!-- AC:END -->
