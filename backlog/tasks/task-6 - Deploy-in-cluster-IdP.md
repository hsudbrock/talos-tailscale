---
id: TASK-6
title: Deploy in-cluster IdP
status: To Do
assignee:
  - Codex
created_date: '2026-04-19 07:19'
labels:
  - auth
  - sso
  - argocd
  - gitops
dependencies:
  - TASK-4
  - TASK-5
documentation:
  - 'https://docs.goauthentik.io/integrations/services/argocd/'
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Deploy the chosen in-cluster identity provider as a GitOps-managed platform app. Recommended default is Authentik unless implementation discovery or user preference selects Keycloak.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 IdP choice is documented; recommended default is Authentik.
- [ ] #2 IdP is deployed from a pinned chart/version.
- [ ] #3 Required persistent storage uses Longhorn.
- [ ] #4 Initial admin/bootstrap secret is handled through the chosen secret mechanism.
- [ ] #5 Access method is documented for the local Tailscale cluster.
- [ ] #6 Basic health validation proves login endpoint and core pods are ready.
<!-- AC:END -->
