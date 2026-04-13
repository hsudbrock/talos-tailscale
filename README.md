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
```

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
