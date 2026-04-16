---
id: TASK-1
title: Test Talos Kubernetes over Tailscale-only node transport
status: In Progress
assignee:
  - Codex
created_date: '2026-04-13 20:24'
updated_date: '2026-04-16 16:10'
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

Extend `make test` beyond syntax checks with a local fake-bin harness that exercises script behavior without network, VM startup, or real secrets. The tests should stub external commands and assert generated configs, command arguments, and safety properties such as not requiring or printing real `.env` values.

Add localhost-only QEMU VNC display support to the VM startup harness so each Talos VM can be viewed with a VNC client. Document the display mapping and update functional tests to assert the VNC arguments.

Improve QEMU VNC readability by adding configurable VM display resolution and a QXL VGA device. Document how to adjust the resolution and update tests to assert the display-device arguments.

Fix the functional test harness so `make test` never deletes or mutates the real `.state/` runtime directory. Add a `STATE_DIR` override to scripts and run tests against a temporary state directory instead.

Add a configurable QEMU display backend. Keep localhost VNC as the default headless-friendly mode, and add GTK mode using `-display gtk,zoom-to-fit=on` for readable local VM consoles. Document the `.env` switch and update tests for both VNC and GTK command generation.

Add a configurable QEMU CPU model for Talos x86-64-v2 compatibility. Default to `max` so TCG emulation exposes a sufficiently modern CPU, and document when to use `host` if KVM is available.

Fix QEMU boot ordering so the first boot can fall back to the ISO on an empty disk, but post-install reboots prefer the installed disk. Change from CD-ROM-first to disk-first-with-CD fallback and update functional tests/documentation.

Fix Talos install disk for QEMU virtio disks. Default the install disk to `/dev/vda`, make it configurable via `INSTALL_DISK`, update config generation, documentation, tests, and local `.env`.

Enable serial console logging in the Talos image so QEMU `-serial file:` receives boot logs. Add Talos Image Factory extra kernel args for `console=ttyS0` while retaining VGA console, update documentation and functional tests, and note that `make image` must be rerun.

Add operator Makefile targets for common debugging and reset actions: tailscale extension logs per node and a disk cleanup target that stops VMs before removing `.state/disks`.

Add configurable worker-node support. Separate control-plane node names from worker node names, generate worker machine configs when workers are enabled, start/apply/validate all nodes, and keep bootstrap/etcd checks scoped to control-plane nodes. Update docs and functional tests so a worker-backed default topology can run general workloads without control-plane tolerations.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented the repo-local harness and documentation. Added README setup/validation/troubleshooting, environment template, QEMU lifecycle scripts, Talos image/config/bootstrap/validation scripts, and a Kubernetes cross-node smoke manifest. Static validation completed: bash syntax checks pass for all scripts, `scripts/generate-configs.sh` succeeds with a dummy schematic ID/auth key, and `talosctl validate --mode metal` passes for all three generated control-plane configs. End-to-end VM/bootstrap validation is not run in this session because it requires a real Tailscale auth key and downloading/booting the Talos factory ISO.

Added Makefile targets as the primary operator interface: env, image, configs, start, apply, bootstrap, validate, stop, clean/reset, and test-local. Updated README setup/testing flow to use Makefile targets while keeping scripts as the implementation/debug layer. Verified `make help` and `make test-local` pass.

Added TDD as an explicit requirement for this task and future changes to the harness: update tests/validation first, then implementation, and require `make test` before completion.

User requested functional script tests. Scope remains within TASK-1 because it directly supports the new TDD requirement and improves validation of the existing harness.

Extended `make test` with functional script behavior tests under `tests/script-behavior.sh`. The test stubs external commands, exercises image preparation, config generation, VM startup command construction, config apply, bootstrap, and validation flows without network, real Tailscale credentials, or VM startup. It also exposed and fixed `.env` precedence/parsing behavior so explicit environment variables override `.env` and quoted values parse correctly. Verified `make test` passes.

User requested a way to see VM screens after serial logs were empty. The running VMs were started with `-display none`, so display cannot be attached retroactively; update the harness so future starts expose localhost-only VNC displays.

Added localhost-only VNC display support to `scripts/start-vms.sh`, defaulting to QEMU displays `:1`, `:2`, and `:3` / TCP ports 5901-5903. Documented the VNC mapping in README and added functional test assertions for the QEMU `-display vnc=127.0.0.1:<display>` arguments. Verified `make test` passes.

User reported the VNC console is too small to read. Update the harness to start VMs with a larger QEMU display by default.

Improved VNC readability defaults by adding configurable `VM_DISPLAY_DEVICE`, `VM_DISPLAY_WIDTH`, and `VM_DISPLAY_HEIGHT` settings, defaulting to `qxl-vga` at `1280x800`. Updated README and functional tests. Verified `make test` passes. Existing `.env` files need these settings added manually or removed/recreated from the example to use the new defaults.

Discovered a test harness bug: `tests/script-behavior.sh` cleaned up `${ROOT_DIR}/.state`, which can delete the real downloaded Talos ISO and runtime state. Fix tests to use an isolated temporary `STATE_DIR`.

Fixed the destructive test-harness cleanup bug. `scripts/lib.sh` now supports a `STATE_DIR` override, and `tests/script-behavior.sh` runs entirely against a temporary `STATE_DIR` instead of `${ROOT_DIR}/.state`. Verified `make test` passes and the real `.state/assets/talos-v1.11.5-tailscale-metal-amd64.iso` remains present afterward.

Adjusted VNC readability approach after `qxl-vga`/1280x800 still produced a too-small console. The default is now simple QEMU `VGA` with no forced resolution, leaving the guest surface small so the VNC viewer can scale it up. README now documents TigerVNC F8 scaling/fullscreen and keeps `qxl-vga` as an optional experiment. Verified `make test` passes.

Added TigerVNC helper targets `make vnc-cp1`, `make vnc-cp2`, and `make vnc-cp3`, using `xtigervncviewer -FullScreen -RemoteResize=0` to avoid guest framebuffer resize and make the console more readable via fullscreen viewer scaling. README documents the helper targets and F8 menu behavior. Verified `make test` and `make help` pass.

VNC remains unreadably small even after display-device adjustments and TigerVNC fullscreen. QEMU supports `gtk,zoom-to-fit=on`, so add an alternate local GUI display mode instead of continuing to tune VNC.

Added `VM_DISPLAY_BACKEND` with `vnc` default and `gtk` option. GTK mode starts QEMU windows with `-display gtk,zoom-to-fit=on,show-menubar=on` for more readable local console debugging when VNC client scaling is inadequate. Updated README and functional tests; verified `make test` passes.

User observed Talos boot failure: x86 microarchitecture level 2 required, emulated CPU only level 1. This is caused by QEMU's default CPU model. Update harness to pass an explicit CPU model.

Added `VM_CPU_MODEL`, defaulting to `max`, and updated QEMU startup to pass `-cpu ${VM_CPU_MODEL}`. Also set local `.env` to `VM_CPU_MODEL=max` without printing secrets. This addresses Talos' x86-64-v2 requirement under QEMU TCG where the default CPU model reports only x86-64-v1. Verified `make test` passes.

After `make apply`, nodes rebooted back into maintenance mode. The QEMU command used `-boot order=d`, so the ISO remained preferred over the installed disk. Change boot order to prefer disk after install.

Changed QEMU boot order from `order=d` to `order=cd`: disk first with CD-ROM fallback. This lets empty disks boot the Talos ISO initially, then post-install reboots prefer the installed disk instead of returning to ISO maintenance mode. Updated README and functional tests; verified `make test` passes.

Talos install failed because generated configs target `/dev/sda`, but QEMU starts the disk with `if=virtio`, which exposes it as `/dev/vda` in the guest. Update the harness to use `/dev/vda`.

Fixed install disk mismatch. `INSTALL_DISK` now defaults to `/dev/vda`, `scripts/generate-configs.sh` passes it to `talosctl gen config --install-disk`, README explains why QEMU virtio disks use `/dev/vda`, and local `.env` was updated without printing secrets. Verified `make test` passes. Existing generated Talos configs must be regenerated with `make configs` before reapplying.

User cannot read logs comfortably from the display. The existing QEMU serial log files are empty because the Talos image boots primarily on VGA. Add serial console kernel args to the generated image schematic so boot logs are written to the per-node serial log files.

User requested Makefile targets for Tailscale logs and removing VM disks. Add these as non-secret operator helpers and cover them in docs/tests.

Added Makefile targets `logs-tailscale`, `logs-tailscale-cp1`, `logs-tailscale-cp2`, `logs-tailscale-cp3`, and `clean-disks`. `clean-disks` depends on `stop` before removing `.state/disks`. README documents the targets, and functional tests assert their dry-run command output. Verified `make test` and `make help` pass.

Observed live test state: Tailscale is running on all three VMs and Talos sees tailscale0 addresses. After `make apply`, etcd remains in Preparing before bootstrap, which is expected until the cluster is bootstrapped. Next user action is `make bootstrap`, then `make validate`.

Fixed and verified bootstrap flow during live testing. `scripts/bootstrap.sh` now waits for the Talos API with `--endpoints 127.0.0.1:<port> --nodes 127.0.0.1` instead of waiting for full health before bootstrap. `make test` passes, live `make bootstrap` succeeds, and all three etcd members are healthy using Tailscale peer/client URLs.

Fixed validation smoke workload for all-control-plane cluster and tailnet-only pod networking. The smoke deployment now tolerates control-plane taints, and generated Talos configs force flannel to use `--iface=tailscale0`; live cluster was patched and stale flannel `10.0.2.15` annotations were cleared. `make test` passes and live `make validate` now succeeds, with smoke pods spread across all three nodes and service DNS reachability confirmed.

Updated validation cleanup behavior: `scripts/validate.sh` now deletes the `tailnet-smoke` Deployment and Service via an EXIT trap after validation. Added functional test assertions for the cleanup command. Verified `make test` passes, live `make validate` passes, and `kubectl get deploy,svc -l app=tailnet-smoke` returns no resources afterward.

Added configurable worker-node support. The harness now separates `CONTROL_PLANE_NODE_NAMES` and `WORKER_NODE_NAMES`, generates both control-plane and worker Talos configs, starts/applies/validates all nodes, scopes bootstrap/etcd checks to control planes, and removes control-plane tolerations from the smoke workload so normal workloads schedule on workers. Verified `make test` passes and real `talosctl validate --mode metal` accepts both generated control-plane and worker configs with a dummy auth key.

Expanded the default worker topology to three workers. Updated `.env`, the example env, README, Makefile helper targets, and functional tests for `talos-ts-worker1`, `talos-ts-worker2`, and `talos-ts-worker3` with API ports 50004-50006 and VNC ports 5904-5906. Verified `make test` passes and real `talosctl validate --mode metal` accepts generated control-plane and worker configs with the three-worker topology.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 TDD is followed for future changes: add or update the relevant test/validation target before changing implementation, then make it pass.
- [x] #2 `make test` passes before the task is marked Done.
<!-- DOD:END -->
