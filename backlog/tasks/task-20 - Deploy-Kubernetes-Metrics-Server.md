---
id: TASK-20
title: Deploy Kubernetes Metrics Server
status: Done
assignee:
  - '@Codex'
created_date: '2026-04-23 14:32'
updated_date: '2026-04-28 20:21'
labels:
  - metrics
  - kubernetes
  - gitops
dependencies:
  - TASK-2
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Deploy Kubernetes Metrics Server so kubectl top works against the local Talos cluster. Scope should fit this repo's GitOps model and account for Talos/local-cluster TLS or kubelet address requirements discovered during implementation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Metrics Server is installed through Argo CD or the existing GitOps root with a pinned chart or manifest version.
- [x] #2 Configuration is documented and justified for this Talos-over-Tailscale cluster, including any kubelet TLS or preferred-address settings.
- [x] #3 kubectl top nodes returns CPU and memory usage for all ready nodes.
- [x] #4 kubectl top pods works for at least one namespace with running pods.
- [x] #5 README documents how to sync, validate, and troubleshoot Metrics Server.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Verified Metrics Server through GitOps on April 28, 2026. The Argo CD child application metrics-server synced healthy from remote main, the aggregated APIService v1beta1.metrics.k8s.io reported Available=True, kubectl top nodes returned CPU and memory usage for all ready nodes, and kubectl top pods -n kube-system returned pod metrics. The required Talos-specific configuration was --kubelet-preferred-address-types=InternalIP,Hostname plus --kubelet-insecure-tls because the nodes advertise Tailscale 100.x InternalIP addresses that are reachable in-cluster, but the local Talos kubelet serving certificates do not include those IPs as SANs.
<!-- SECTION:FINAL_SUMMARY:END -->
