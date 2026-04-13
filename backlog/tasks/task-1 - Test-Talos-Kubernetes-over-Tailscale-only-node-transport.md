---
id: TASK-1
title: Test Talos Kubernetes over Tailscale-only node transport
status: In Progress
assignee:
  - Codex
created_date: '2026-04-13 20:24'
updated_date: '2026-04-13 20:38'
labels:
  - talos
  - tailscale
  - kubernetes
  - local-test
dependencies: []
documentation:
  - 'https://www.talos.dev/latest/talos-guides/configuration/system-extensions/'
  - 'https://www.talos.dev/latest/advanced/extension-services/'
  - >-
    https://www.talos.dev/v1.10/reference/configuration/extensions/extensionserviceconfig/
  - 'https://www.talos.dev/v1.11/talos-guides/network/multihoming/'
  - 'https://tailscale.com/kb/1081/magicdns/'
  - 'https://tailscale.com/docs/features/containers/docker/docker-params'
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Validate that Talos Kubernetes nodes can be started from isolated networks and form a 3-control-plane cluster using Tailscale as the only inter-node transport. The repository should contain reproducible local QEMU scripts and documentation for setup, execution, validation, troubleshooting, and teardown. Tailscale credentials must be supplied from the environment and never committed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The repo documents the intended topology, prerequisites, setup, execution, validation, and teardown.
- [ ] #2 Local QEMU VMs can be started with no shared VM-to-VM LAN path.
- [ ] #3 A 3-control-plane Talos cluster can be generated and bootstrapped.
- [x] #4 All Talos, Kubernetes, kubelet, and etcd node addressing is configured to prefer Tailscale 100.64.0.0/10 addresses.
- [x] #5 The Tailscale auth key is supplied from the environment and is never committed.
- [x] #6 Validation commands prove Talos API access, Kubernetes API access, etcd peer health, node IP selection, and cross-node workload behavior.
- [x] #7 Troubleshooting notes cover Tailscale auth failure, extension startup failure, wrong node IP selection, and MagicDNS issues.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Implement a repo-contained local test harness for Talos Kubernetes over Tailscale-only transport.

1. Add a README that documents the goal, local QEMU topology, prerequisites, setup, execution, validation, teardown, and troubleshooting.
2. Add a non-secret environment template for cluster name, Talos/Kubernetes versions, node names, disk/memory settings, and TS_AUTHKEY input.
3. Add scripts that prepare a Talos image with the Tailscale system extension, generate Talos machine configs with Tailscale extension config and 100.64.0.0/10 address selection, start/stop isolated QEMU nodes, bootstrap the cluster, and validate Talos/Kubernetes/etcd/node networking.
4. Keep credentials out of git by reading TS_AUTHKEY from the environment or an ignored .env file only.
5. Add basic shell syntax validation and update TASK-1 acceptance criteria/final notes with implementation and validation results.

Add a thin Makefile as the primary operator interface for the existing scripts, with targets for setup guidance, image preparation, config generation, VM lifecycle, apply, bootstrap, validation, and cleanup. Keep scripts as the implementation layer and document both Makefile and direct script usage.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented the repo-local harness and documentation. Added README setup/validation/troubleshooting, environment template, QEMU lifecycle scripts, Talos image/config/bootstrap/validation scripts, and a Kubernetes cross-node smoke manifest. Static validation completed: bash syntax checks pass for all scripts, `scripts/generate-configs.sh` succeeds with a dummy schematic ID/auth key, and `talosctl validate --mode metal` passes for all three generated control-plane configs. End-to-end VM/bootstrap validation is not run in this session because it requires a real Tailscale auth key and downloading/booting the Talos factory ISO.

Added Makefile targets as the primary operator interface: env, image, configs, start, apply, bootstrap, validate, stop, clean/reset, and test-local. Updated README setup/testing flow to use Makefile targets while keeping scripts as the implementation/debug layer. Verified `make help` and `make test-local` pass.
<!-- SECTION:NOTES:END -->
