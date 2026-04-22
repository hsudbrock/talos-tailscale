---
id: TASK-19
title: Expose cluster services through the Tailscale Kubernetes operator
status: To Do
assignee:
  - '@Codex'
created_date: '2026-04-22 21:42'
labels:
  - tailscale
  - operator
  - networking
  - gitops
dependencies: []
references:
  - 'https://tailscale.com/kb/1236/kubernetes-operator'
  - 'https://tailscale.com/kb/1439/kubernetes-operator-cluster-ingress'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Install and manage the Tailscale Kubernetes operator through GitOps, then expose at least one in-cluster service over the tailnet using the operator-managed resources. Scope includes documenting the tailnet auth and ACL assumptions needed for this repo so service exposure is deliberate rather than ad hoc.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Decision documents which Tailscale operator exposure model is used first (for example ingress, proxy service, or operator-managed Service/Ingress path) and why.
- [ ] #2 The Tailscale Kubernetes operator is installed through Argo CD or the existing GitOps root with a pinned version.
- [ ] #3 At least one cluster service is exposed successfully to the tailnet through the operator-managed path.
- [ ] #4 README documents required Tailscale auth, tags, ACL or policy assumptions, and the operator workflow for adding another exposed service.
- [ ] #5 Validation proves end-to-end access from an authorized tailnet client and confirms unauthorized exposure is not the default.
<!-- AC:END -->
