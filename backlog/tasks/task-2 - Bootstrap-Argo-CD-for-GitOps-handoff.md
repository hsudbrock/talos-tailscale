---
id: TASK-2
title: Bootstrap Argo CD for GitOps handoff
status: In Progress
assignee:
  - Codex
created_date: '2026-04-19 06:57'
updated_date: '2026-04-19 07:05'
labels:
  - argocd
  - gitops
  - kubernetes
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a repo-contained Argo CD bootstrap path for the Talos over Tailscale cluster. The bootstrap should install Argo CD after Kubernetes is available and apply a root Application so subsequent cluster resources can be managed by GitOps.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The repo provides a make target and script to install Argo CD using the generated kubeconfig.
- [x] #2 The Argo CD version and root Application source are configurable from .env without committing secrets.
- [x] #3 The bootstrap applies a root Argo CD Application that points to the repository GitOps path.
- [x] #4 Operator helpers exist for Argo CD status, UI port-forwarding, and initial admin password retrieval.
- [x] #5 Local non-secret tests cover the new bootstrap script and Makefile targets.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add Argo CD environment defaults to the example .env.\n2. Add Argo CD bootstrap manifests for namespace and root Application.\n3. Add scripts/bootstrap-argocd.sh to install pinned Argo CD manifests and apply the root Application.\n4. Add Makefile targets for argocd, argocd-status, argocd-ui, and argocd-password.\n5. Extend tests/script-behavior.sh with fake kubectl/curl coverage for the new flow.\n6. Update README with the new bootstrap handoff workflow and run make test.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented Argo CD bootstrap support. Added scripts/bootstrap-argocd.sh, Makefile targets argocd/argocd-status/argocd-ui/argocd-password, Argo CD .env defaults, a minimal GitOps root kustomization, README documentation, and fake-bin functional tests. Verified make test passes. Live make argocd installed Argo CD v3.3.6 successfully after adding longer kubectl request timeouts; all Argo CD pods are Running. The root Application talos-tailnet-local-root is Healthy but Sync Unknown until the new gitops path exists on the configured remote branch.

Post-install live make validate also passes with Argo CD present. The smoke workload rolled out on worker nodes and service reachability succeeded.

Fixed Makefile help coverage for the new Argo CD helper targets. Added test assertions that make help includes argocd, argocd-status, argocd-ui, and argocd-password. Verified make test passes.
<!-- SECTION:NOTES:END -->
