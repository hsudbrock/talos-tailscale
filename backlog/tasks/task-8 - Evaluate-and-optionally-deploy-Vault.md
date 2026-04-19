---
id: TASK-8
title: Evaluate and optionally deploy Vault
status: To Do
assignee:
  - Codex
created_date: '2026-04-19 07:19'
labels:
  - vault
  - secrets
  - storage
  - gitops
dependencies:
  - TASK-4
  - TASK-6
documentation:
  - 'https://developer.hashicorp.com/vault/docs/deploy/kubernetes/helm'
  - >-
    https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-raft-deployment-guide
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Decide whether an in-cluster Vault is needed after the initial secret bootstrap and identity layers exist, and deploy it only if the operational tradeoff is justified.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Decision document compares Vault against the chosen initial secret mechanism.
- [ ] #2 If implemented, Vault is deployed with pinned chart/version and persistent storage.
- [ ] #3 Unseal, backup, restore, and disaster recovery expectations are documented.
- [ ] #4 Vault is not required to bootstrap its own initial secrets.
- [ ] #5 If deferred, the task records why and what future need would reopen it.
<!-- AC:END -->
