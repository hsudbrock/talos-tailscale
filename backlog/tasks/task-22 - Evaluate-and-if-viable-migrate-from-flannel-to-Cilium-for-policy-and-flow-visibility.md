---
id: TASK-22
title: >-
  Evaluate and, if viable, migrate from flannel to Cilium for policy and flow
  visibility
status: Done
assignee:
  - '@Codex'
created_date: '2026-04-28 20:27'
updated_date: '2026-04-28 20:54'
labels:
  - networking
  - cni
  - cilium
  - networkpolicy
  - observability
  - hubble
  - tailscale
  - talos
dependencies: []
references:
  - 'https://docs.cilium.io/en/stable/network/kubernetes/policy.html'
  - 'https://docs.cilium.io/en/stable/observability/hubble/'
  - 'https://docs.cilium.io/en/stable/network/clustermesh/clustermesh/'
  - 'https://docs.cilium.io/en/stable/network/concepts/routing/'
  - 'https://kubernetes.io/docs/concepts/services-networking/network-policies/'
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Assess whether this Talos-over-Tailscale cluster should move from flannel to Cilium in order to gain enforceable NetworkPolicy support and first-class network flow visibility. The work must validate Cilium against this repo's specific constraints: Tailscale 100.x InternalIP addressing, Talos node behavior, existing Argo CD GitOps flow, Longhorn, Metrics Server, and current smoke workloads. If the evaluation is positive, carry the change through a documented migration and verification path with a rollback plan.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Decision is documented between staying on flannel and migrating to Cilium, with explicit tradeoffs for NetworkPolicy support, flow visibility, operational complexity, and Tailscale/Talos compatibility.
- [x] #2 A Cilium deployment mode is selected and justified for this repo (including overlay vs native routing, kube-proxy retention vs replacement, and whether to enable Hubble Relay/UI and WireGuard).
- [x] #3 Standard Kubernetes NetworkPolicy enforcement is demonstrated with at least one deny-by-default and one explicit allow smoke test.
- [x] #4 Network flow visibility is demonstrated with Hubble for at least one workload path, including enough output to identify source, destination, verdict, and protocol.
- [x] #5 Compatibility is verified for Argo CD, Longhorn, Metrics Server, and the existing validation/smoke workloads after the CNI change or in a documented evaluation environment.
- [x] #6 Migration and rollback steps are documented, including any Talos config, Tailscale/InternalIP, MTU, or kube-proxy implications discovered during testing.
- [x] #7 If migration is accepted, the repo installs and manages Cilium through the existing GitOps/bootstrap model with pinned versions and updated README guidance.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Live evaluation used a from-scratch rebuild of the local Talos-over-Tailscale cluster with CLUSTER_CNI=cilium and CILIUM_VERSION=1.19.3. The accepted first-pass mode keeps kube-proxy enabled, uses VXLAN tunnel routing, enables Hubble Relay/UI, and leaves WireGuard and ClusterMesh out of the initial migration scope. Base cluster validation, Metrics Server, Sealed Secrets, Longhorn, the Longhorn-backed storage smoke workload, and the sealed secret smoke workload all ran successfully on the rebuilt Cilium cluster. The clean-cluster rebuild also exposed an ordering issue in the GitOps root: secret-smoke.yaml can be validated before the Sealed Secrets CRD exists. The repo now addresses that by syncing the Sealed Secrets child app earlier and marking the SealedSecret with SkipDryRunOnMissingResource.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Evaluated and accepted a migration from flannel to Cilium for this repo on April 28, 2026. The repo now defaults Talos config generation to CLUSTER_CNI=cilium, renders a pinned Cilium 1.19.3 bootstrap manifest during make configs, and boots Cilium as the primary CNI through Talos inline manifests while keeping kube-proxy enabled and using VXLAN tunnel mode. Standard Kubernetes NetworkPolicy enforcement was proven with a deny-by-default plus explicit allow smoke test, and Hubble showed both FORWARDED and Policy denied DROPPED flows for the same workload path. Compatibility was verified on a from-scratch evaluation cluster for Argo CD, Metrics Server, Sealed Secrets, Longhorn, the Longhorn storage smoke workload, and the sealed secret smoke workload, with rollback documented as setting CLUSTER_CNI=flannel and regenerating/reapplying or rebuilding the cluster.
<!-- SECTION:FINAL_SUMMARY:END -->
