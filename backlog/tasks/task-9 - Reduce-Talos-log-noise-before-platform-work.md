---
id: TASK-9
title: Reduce Talos log noise before platform work
status: Done
assignee:
  - Codex
created_date: '2026-04-19 07:22'
updated_date: '2026-04-22 16:47'
labels:
  - talos
  - logs
  - observability
  - cleanup
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Investigate and reduce recurring or avoidable Talos/Kubernetes log errors so genuine future failures are easier to spot before adding Longhorn, secrets, and SSO components.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A log audit command or script summarizes current warning/error patterns across Talos services without dumping full noisy logs.
- [x] #2 The audit distinguishes historical boot/convergence noise from currently recurring errors.
- [x] #3 Any actionable recurring errors are fixed or documented with rationale if they are expected and harmless.
- [x] #4 Existing validation confirms the cluster remains healthy after any changes.
- [x] #5 README documents the clean-log check and known acceptable transient messages.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Investigating Talos host DNS warnings caused by MagicDNS hostname resolution through 127.0.0.53 on nodes. Implement ResolverConfig generation with Tailscale DNS and configurable search domain, then validate generated configs and local tests.

Implemented ResolverConfig generation in scripts/generate-configs.sh with default resolvers 100.100.100.100, 9.9.9.9, 1.1.1.1, and 8.8.8.8 plus configurable TAILSCALE_SEARCH_DOMAIN. Updated README, env example, local .env, and script behavior tests. Freshly regenerated worker config contains the expected ResolverConfig document; live post-bootstrap verification is still pending because Talos/Kubernetes API checks from this environment are currently timing out or hanging.

Added scripts/logs-audit.sh plus make logs-audit to summarize known recurring Talos warning patterns by node and service, classifying them as historical or recurring based on a recent log window.
Changed generated Tailscale ExtensionServiceConfig to use TAILSCALE_ACCEPT_DNS=false by default because Talos host DNS is already managed through ResolverConfig and the extension cannot rewrite /etc/resolv.conf on Talos. Updated README, env example, and behavior tests.
Live audit on the current cluster shows the original machined StaticEndpointController DNS warning is gone. The only recurring warning pattern now is ext-tailscale dns-write failures on all nodes, which should disappear after regenerating and rolling out the updated machine configs.

Live rebuild verification on 2026-04-22: make logs-audit now reports no recurring warning patterns after rebuilding the cluster with TS_ACCEPT_DNS=false and Talos ResolverConfig in place. The prior machined StaticEndpointController DNS warnings are gone; remaining validation noise is limited to the temporary tailnet-curl PodSecurity warning, which is tracked separately in TASK-16.
<!-- SECTION:NOTES:END -->
