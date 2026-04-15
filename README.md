# Talos Kubernetes over Tailscale-only transport

This repository contains a local test harness for a Talos Kubernetes cluster
whose nodes have no shared node-to-node network. Each node runs as a local QEMU
VM with isolated user-mode networking: it can reach the internet and the host
through explicit port forwards, but it is not attached to a shared bridge with
the other VMs.

The cluster transport is Tailscale. The test configures Talos so kubelet node
IPs and etcd advertised addresses prefer the Tailscale CGNAT range
`100.64.0.0/10`. KubeSpan is intentionally not enabled.

## Topology

- Cluster: `talos-tailnet-local`
- Nodes: `talos-ts-cp1`, `talos-ts-cp2`, `talos-ts-cp3`
- Role: all three nodes are Talos control planes
- Kubernetes endpoint: `https://talos-ts-cp1:6443`
- VM networking: separate QEMU user-mode network per VM
- First-boot access: localhost Talos API forwards only
- Steady-state access: Tailscale MagicDNS hostnames
- VM screens: localhost-only VNC displays

## Prerequisites

- `talosctl`
- `qemu-system-x86_64`
- `qemu-img`
- `kubectl`
- `curl`
- A Tailscale tailnet with MagicDNS enabled
- A reusable or ephemeral Tailscale auth key

The auth key is read from `TS_AUTHKEY` in the environment or from `.env`.
Do not commit `.env`.

## Create a Tailscale auth key

In the Tailscale admin console, open the Keys page and generate an auth key.
You must have permission to manage auth keys in the tailnet.

Recommended options for this local test:

- Reusable: enabled, because the same key is used by all three Talos nodes.
- Ephemeral: enabled, so test nodes are removed from the tailnet after they go
  offline.
- Pre-approved: enabled if your tailnet requires device approval.
- Tags: optional. If you use tags, make sure your ACLs allow the tagged nodes to
  reach each other and the host where you run `talosctl`.

Copy the generated key into `.env`:

```bash
TS_AUTHKEY=tskey-auth-...
```

Reusable auth keys are sensitive. Keep `.env` local, do not paste the key into
shell history, and revoke the key from the Keys page after the test if you no
longer need it.

## Development requirement

Use TDD for changes to this harness. Add or update the relevant validation first,
usually through `make test`, then change the implementation and make the test
pass. Run `make test` before considering a change complete. The test target runs
plain Bash tests with stubbed external commands, so it does not read `.env`, use
a real Tailscale auth key, download images, or start VMs.

## Setup

```bash
make env
$EDITOR .env
```

Set `TS_AUTHKEY` to a valid auth key. The remaining defaults are suitable for
the local 3-control-plane test.

Build and download a Talos ISO with the official Tailscale system extension:

```bash
make image
```

Generate Talos machine configs:

```bash
make configs
```

Start the VMs:

```bash
make start
```

The VM boot order prefers disk first and falls back to the Talos ISO. On a fresh
empty disk, QEMU boots the ISO so Talos can install. After `make apply` installs
Talos to the VM disk and reboots, the same VM boots from disk instead of falling
back into ISO maintenance mode.

By default, `make start` exposes localhost-only VNC for each VM. Connect a VNC
client to:

| Node | VNC address |
| --- | --- |
| `talos-ts-cp1` | `127.0.0.1:5901` |
| `talos-ts-cp2` | `127.0.0.1:5902` |
| `talos-ts-cp3` | `127.0.0.1:5903` |

These VNC listeners are bound to localhost only. They show the QEMU VGA output;
Talos does not provide an interactive login shell, so operational debugging
still happens through `talosctl`.

The default VNC console uses QEMU `VGA`. With TigerVNC, use the helper targets
so the viewer opens fullscreen and does not ask the VM to resize its framebuffer:

```bash
make vnc-cp1
make vnc-cp2
make vnc-cp3
```

You can also run the viewer directly:

```bash
xtigervncviewer -FullScreen -RemoteResize=0 127.0.0.1::5901
```

Use the F8 menu to leave fullscreen. If the text is still small, the remaining
control is in the VNC client: disable remote resize and use client-side scaling
or fullscreen.

If the VNC console is still too small to read, use QEMU's local GTK display
backend instead. Add this to `.env`, then restart the VMs from your desktop
session:

```bash
VM_DISPLAY_BACKEND=gtk
```

Then run:

```bash
make stop
make start
```

GTK mode opens one QEMU window per VM with `zoom-to-fit=on`. It is intended for
local interactive debugging and does not use the VNC ports.

The default CPU model is `max` because Talos requires x86-64-v2 and QEMU's
default emulated CPU can be too old. If KVM is available and you want to expose
the host CPU directly, set this in `.env`:

```bash
VM_CPU_MODEL=host
```

The default install disk is `/dev/vda` because the QEMU disk is attached as a
virtio block device. If you change the QEMU disk bus, update `INSTALL_DISK` in
`.env` and rerun `make configs`.

If you want to experiment with a different display device or explicit guest
resolution, set these values in `.env`:

```bash
VM_DISPLAY_DEVICE=qxl-vga
VM_DISPLAY_WIDTH=1280
VM_DISPLAY_HEIGHT=800
```

Apply machine configs through the localhost Talos API forwards:

```bash
make apply
```

Bootstrap Kubernetes:

```bash
make bootstrap
```

Validate the cluster over Tailscale:

```bash
make validate
```

The Makefile targets are thin wrappers around the scripts in `scripts/`. Use the
scripts directly when debugging a specific step.

## What the scripts generate

Runtime state is written under `.state/`:

- `.state/assets/`: Talos ISO with the Tailscale extension
- `.state/disks/`: QEMU node disks
- `.state/talos/generated/`: generated per-node Talos configs
- `.state/kubeconfig/config`: Kubernetes client config
- `.state/logs/`: QEMU serial logs

Generated Talos configs contain the Tailscale auth key. `.state/` is ignored by
git, but treat it as local secret-bearing runtime state.

Generated machine configs include a per-node `ExtensionServiceConfig`:

```yaml
apiVersion: v1alpha1
kind: ExtensionServiceConfig
name: tailscale
environment:
  - TS_AUTHKEY=...
  - TS_HOSTNAME=talos-ts-cp1
  - TS_ACCEPT_DNS=true
  - TS_STATE_DIR=/var/lib/tailscale
  - TS_EXTRA_ARGS=--reset
```

The common Talos patch pins cluster-facing address selection to Tailscale:

```yaml
machine:
  kubelet:
    nodeIP:
      validSubnets:
        - 100.64.0.0/10
cluster:
  etcd:
    advertisedSubnets:
      - 100.64.0.0/10
  network:
    cni:
      name: flannel
      flannel:
        extraArgs:
          - --iface=tailscale0
```

The flannel argument is required in this QEMU topology. Without it, flannel
auto-detects the identical per-VM QEMU NAT address `10.0.2.15`, which breaks
pod-to-pod and ClusterIP service routing.

## Validation checklist

Run:

```bash
make validate
```

The validation covers:

- Talos API access through Tailscale hostnames
- `ext-tailscale` service status on every node
- etcd membership and health
- Kubernetes node readiness and InternalIP selection
- A small cross-node workload and service reachability check

To inspect Tailscale extension logs during bootstrap/debugging:

```bash
make logs-tailscale
make logs-tailscale-cp1
make logs-tailscale-cp2
make logs-tailscale-cp3
```

For additional manual inspection:

```bash
export TALOSCONFIG=.state/talos/generated/talosconfig
export KUBECONFIG=.state/kubeconfig/config

talosctl --nodes talos-ts-cp1,talos-ts-cp2,talos-ts-cp3 service ext-tailscale
talosctl --nodes talos-ts-cp1,talos-ts-cp2,talos-ts-cp3 etcd members
kubectl get nodes -o wide
kubectl get pods -l app=tailnet-smoke -o wide
```

Node InternalIPs and etcd advertised peer addresses should be in
`100.64.0.0/10`.

## Teardown

Stop the VMs:

```bash
make stop
```

Remove local runtime state:

```bash
make clean
```

To keep the downloaded ISO and generated configs but reset the VM disks:

```bash
make clean-disks
```

Remove ephemeral Tailscale devices from the admin console if your auth key did
not create ephemeral nodes.

## Troubleshooting

### Tailscale auth fails

Check the serial log:

```bash
tail -n 200 .state/logs/talos-ts-cp1.log
```

Verify that `.env` contains `TS_AUTHKEY` and that the key is still valid. If the
key is tagged, make sure the tag is allowed by your tailnet ACLs.

### Tailscale extension is not running

Confirm the image was prepared before config generation:

```bash
cat .state/schematic.id
talosctl --nodes 127.0.0.1:50001 --talosconfig .state/talos/generated/talosconfig service ext-tailscale
```

If the service does not exist, rerun `scripts/prepare-image.sh`,
`scripts/generate-configs.sh`, and recreate the VM disks.

### Nodes choose the QEMU address instead of Tailscale

Check:

```bash
kubectl get nodes -o wide
talosctl --nodes talos-ts-cp1,talos-ts-cp2,talos-ts-cp3 etcd members
```

If addresses are not in `100.64.0.0/10`, wait until `ext-tailscale` is healthy
on every node, then restart the affected services:

```bash
talosctl --nodes talos-ts-cp1,talos-ts-cp2,talos-ts-cp3 service kubelet restart
talosctl --nodes talos-ts-cp1,talos-ts-cp2,talos-ts-cp3 service etcd restart
```

### MagicDNS does not resolve node names

Check from the host:

```bash
tailscale status
tailscale ping talos-ts-cp1
```

Ensure MagicDNS is enabled in the tailnet. If MagicDNS is disabled, use the
Tailscale IPs directly in `talosctl --nodes` and update generated configs to use
an IP-based control-plane endpoint.
