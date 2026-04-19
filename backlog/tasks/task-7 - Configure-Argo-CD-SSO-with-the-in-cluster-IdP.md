---
id: TASK-7
title: Configure Argo CD SSO with the in-cluster IdP
status: To Do
assignee:
  - Codex
created_date: '2026-04-19 07:19'
labels:
  - argocd
  - sso
  - auth
  - rbac
dependencies:
  - TASK-6
documentation:
  - 'https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/'
  - >-
    https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/keycloak/
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Configure Argo CD to authenticate through the in-cluster IdP using OIDC, while retaining a safe fallback path during rollout.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Argo CD OIDC config is managed declaratively.
- [ ] #2 Argo CD RBAC maps an IdP admin group to role:admin.
- [ ] #3 Local admin remains enabled until SSO is verified.
- [ ] #4 Validation confirms Argo CD reports SSO config and the root app remains Synced/Healthy.
- [ ] #5 README documents login flow, fallback admin access, and rollback steps.
<!-- AC:END -->
