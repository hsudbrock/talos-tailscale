---
id: TASK-20
title: Deploy Kubernetes Metrics Server
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-04-23 14:32'
updated_date: '2026-04-28 20:15'
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
- [ ] #1 Metrics Server is installed through Argo CD or the existing GitOps root with a pinned chart or manifest version.
- [ ] #2 Configuration is documented and justified for this Talos-over-Tailscale cluster, including any kubelet TLS or preferred-address settings.
- [ ] #3 kubectl top nodes returns CPU and memory usage for all ready nodes.
- [ ] #4 kubectl top pods works for at least one namespace with running pods.
- [ ] #5 README documents how to sync, validate, and troubleshoot Metrics Server.
<!-- AC:END -->
