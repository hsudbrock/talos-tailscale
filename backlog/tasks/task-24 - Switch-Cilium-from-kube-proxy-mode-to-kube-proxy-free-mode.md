---
id: TASK-24
title: Switch Cilium from kube-proxy mode to kube-proxy-free mode
status: Done
assignee:
  - '@Codex'
created_date: '2026-04-28 21:05'
updated_date: '2026-04-29 16:41'
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
- [x] #1 A deployment design is selected and documented for kube-proxy-free Cilium in this repo, including bootstrap sequencing, required API server host/port settings, and any Talos-specific or multi-interface node-IP considerations.
- [x] #2 The repo is updated so bootstrap and steady-state cluster config run Cilium in kube-proxy-free mode with pinned versions and documented rationale.
- [x] #3 kube-proxy is removed or disabled in the evaluated cluster in a way that avoids ambiguous coexistence, and Cilium reports kube-proxy replacement enabled in live status output.
- [x] #4 Live validation proves Kubernetes Service functionality for ClusterIP, NodePort or equivalent external exposure in this repo, DNS, and hostPort behavior if it is relied upon.
- [x] #5 Compatibility is verified for Argo CD, Metrics Server, Sealed Secrets, Longhorn, Hubble, and the existing smoke workloads after the migration or in a documented evaluation environment.
- [x] #6 The migration documents and accounts for known connection-disruption risk when switching from kube-proxy to Cilium replacement on an existing cluster, with either a rebuild strategy or explicit cutover steps.
- [x] #7 README validation and troubleshooting guidance is updated for kube-proxy-free operation.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
KubePrism is a required part of the kube-proxy-free evaluation on Talos. In kube-proxy-free mode, Cilium must reach the Kubernetes API before Service IP handling is fully established, so it should not depend on kubernetes.default.svc during bootstrap. Talos provides a per-node localhost API load balancer on port 7445 via KubePrism, and both Talos and Cilium documentation recommend pointing kube-proxy-free Cilium at localhost:7445 in this environment.

Live evaluation used a from-scratch rebuild of the local Talos-over-Tailscale cluster with Cilium 1.19.3 in kube-proxy-free mode. The accepted design keeps VXLAN tunnel routing, explicitly enables Talos KubePrism on localhost:7445, disables Talos bootstrap deployment of kube-proxy, and points Cilium at localhost:7445 for Kubernetes API access during bootstrap. Initial validation exposed a timing issue in scripts/validate.sh: a one-shot curl pod could exit before CoreDNS was ready, which looked like a service failure even though the datapath was correct. The repo now retries the smoke curl until DNS and Service handling converge.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Evaluated and accepted kube-proxy-free Cilium for this repo on April 29, 2026. The repo now renders Cilium with kubeProxyReplacement=true plus k8sServiceHost=localhost and k8sServicePort=7445, and Talos-generated machine configs explicitly enable KubePrism and disable kube-proxy at bootstrap. A from-scratch rebuild validated the design on the live cluster: there is no kube-proxy DaemonSet, Cilium reports KubeProxyReplacement=True, standard Kubernetes NetworkPolicy enforcement passed, Hubble showed both forwarded and policy-denied dropped flows, ClusterIP and NodePort service handling worked, kubectl top nodes returned metrics for all four nodes, Sealed Secrets decrypted the secret-smoke payload, and the Longhorn-backed storage smoke workload reached Running and served its persisted content. The evaluation also tightened validation guidance by making the base curl smoke test retry until DNS and Service resolution are actually ready.
<!-- SECTION:FINAL_SUMMARY:END -->
