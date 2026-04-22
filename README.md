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
- Control planes: `talos-ts-cp1`, `talos-ts-cp2`, `talos-ts-cp3`
- Workers: `talos-ts-worker1`, `talos-ts-worker2`, `talos-ts-worker3`
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
- `k9s` for the optional `make k9s` target
- `curl`
- A Tailscale tailnet with MagicDNS enabled
- A reusable or ephemeral Tailscale auth key

The auth key is read from `TS_AUTHKEY` in the environment or from `.env`.
Do not commit `.env`.

## Create a Tailscale auth key

In the Tailscale admin console, open the Keys page and generate an auth key.
You must have permission to manage auth keys in the tailnet.

Recommended options for this local test:

- Reusable: enabled, because the same key is used by all Talos nodes.
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

Set `TS_AUTHKEY` to a valid auth key. The remaining defaults create a
3-control-plane plus 3-worker local test cluster. Set `ARGOCD_REPO_URL` to a Git
remote that the cluster can reach if you plan to run `make argocd`.

Older `.env` files may still have only `NODE_NAMES`. That continues to work as
an all-control-plane topology. To add workers, replace it with:

```bash
CONTROL_PLANE_NODE_NAMES="talos-ts-cp1 talos-ts-cp2 talos-ts-cp3"
WORKER_NODE_NAMES="talos-ts-worker1 talos-ts-worker2 talos-ts-worker3"
```

If you want Talos host DNS to resolve short MagicDNS names such as
`talos-ts-cp1`, also set your tailnet search suffix:

```bash
TAILSCALE_SEARCH_DOMAIN=tail4d7760.ts.net
```

If you rebuild the cluster frequently and want to avoid stale MagicDNS name
collisions in Tailscale, set a node suffix. A literal value is appended to all
generated node names, and `random` generates a fresh short suffix for each
`make bootstrap-from-scratch` run:

```bash
NODE_NAME_SUFFIX=random
```

Build and download a Talos ISO with the official Tailscale extension plus the
Longhorn-required `iscsi-tools` and `util-linux-tools` extensions:

```bash
make image
```

Generate Talos machine configs:

```bash
make configs
```

The generated worker configs now prepare Longhorn's Talos data path at
`/var/mnt/longhorn`. By default worker VMs also get a second virtio disk
dedicated to Longhorn, and the repo provisions the user volume from that disk
using:

```bash
WORKER_DATA_DISK_GIB=20
LONGHORN_VOLUME_NAME=longhorn
LONGHORN_DISK_SELECTOR='disk.dev_path == "/dev/vdb"'
LONGHORN_VOLUME_MAX_SIZE=16GiB
```

Adjust those in `.env` before `make configs` if your worker storage layout is
different.

Start the VMs:

```bash
make start
```

Restart a single VM by node name:

```bash
make restart-node NODE=talos-ts-worker1
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
| `talos-ts-worker1` | `127.0.0.1:5904` |
| `talos-ts-worker2` | `127.0.0.1:5905` |
| `talos-ts-worker3` | `127.0.0.1:5906` |

These VNC listeners are bound to localhost only. They show the QEMU VGA output;
Talos does not provide an interactive login shell, so operational debugging
still happens through `talosctl`.

The default VNC console uses QEMU `VGA`. With TigerVNC, use the helper targets
so the viewer opens fullscreen and does not ask the VM to resize its framebuffer:

```bash
make vnc-cp1
make vnc-cp2
make vnc-cp3
make vnc-worker1
make vnc-worker2
make vnc-worker3
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
virtio block device. Worker nodes also get a second virtio data disk by default
for Longhorn, which appears as `/dev/vdb`. If you change the QEMU disk bus or
device order, update `INSTALL_DISK`, `WORKER_DATA_DISK_GIB`, and
`LONGHORN_DISK_SELECTOR` in `.env` and rerun `make configs`.

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

Rebuild the cluster from scratch on fresh disks and stop when Kubernetes has
been bootstrapped:

```bash
make bootstrap-from-scratch
```

This target regenerates Talos configs, removes VM disks, starts the VMs, waits
for every localhost Talos API forward to come up, applies the machine configs,
waits again for the post-apply reboots to finish, and then bootstraps
etcd/Kubernetes. When `NODE_NAME_SUFFIX=random`, this flow also refreshes the
stored suffix first so the rebuilt nodes get fresh unique names.

Validate the cluster over Tailscale:

```bash
make validate
```

Install Argo CD and hand off to the root GitOps Application:

```bash
make argocd
make argocd-status
```

Once Longhorn is added as a child Argo CD Application, matching helper targets
are available for routine operations:

```bash
make longhorn-status
make longhorn-sync
make longhorn-ui
```

`make longhorn-ui` port-forwards the Longhorn frontend service to
`http://localhost:8081`.

The Argo CD bootstrap downloads a pinned upstream install manifest into
`.state/argocd/`, installs it into the `argocd` namespace, and applies a root
`Application` pointing at:

```bash
${ARGOCD_REPO_URL}
${ARGOCD_TARGET_REVISION}
${ARGOCD_ROOT_PATH}
```

The default `ARGOCD_VERSION` is pinned in `.env` instead of using `latest`.
Update it deliberately when you want to test a newer Argo CD release.
Argo CD reads from the configured remote repository, not the local working tree,
so commit and push the `gitops/` path before expecting the root Application to
sync.

Force a hard refresh and sync of the root Application after pushing changes:

```bash
make argocd-sync
```

The GitOps root now includes Longhorn as a child Argo CD Application. After
pushing the `gitops/` changes, use:

```bash
make argocd-sync
make longhorn-status
```

The Longhorn child application installs the pinned chart version `v1.11.1` into
the `longhorn-system` namespace, sets the default data path to
`/var/mnt/longhorn`, and uses a single default replica to match this repo's
single-worker layout.

The GitOps root also includes a tiny `storage-smoke` workload that consumes a
Longhorn PVC named `longhorn-demo`. It uses the default `longhorn` storage
class and serves the persisted `/data/index.html` content over HTTP from a
single replica deployment.

After syncing Argo CD, verify the sample workload with:

```bash
KUBECONFIG=.state/kubeconfig/config kubectl get pvc,pod,svc -n storage-smoke
KUBECONFIG=.state/kubeconfig/config kubectl exec -n storage-smoke deploy/longhorn-demo -- cat /data/index.html
```

That second command should print `longhorn persistent storage ok`.

Open k9s with the generated kubeconfig:

```bash
make k9s
```

Open the Argo CD UI with a localhost port-forward:

```bash
make argocd-ui
```

Then browse to `https://localhost:8080`. Retrieve the initial admin password:

```bash
make argocd-password
```

The Makefile targets are thin wrappers around the scripts in `scripts/`. Use the
scripts directly when debugging a specific step.

## Preparing for Longhorn

Before installing Longhorn through Argo CD, make sure the nodes pick up both the
image-level and machine-config-level prerequisites:

```bash
make image
make configs
make apply
```

`make image` refreshes the Talos schematic so newly installed or upgraded nodes
include `siderolabs/iscsi-tools` and `siderolabs/util-linux-tools`.
`make configs` regenerates the worker configs with:

- a kubelet bind mount for `/var/mnt/longhorn`
- a `UserVolumeConfig` named `longhorn`, which Talos mounts at
  `/var/mnt/longhorn`
- a disk selector that points to the worker's dedicated `/dev/vdb` data disk
- a default `maxSize` of `16GiB`, which you can override with
  `LONGHORN_VOLUME_MAX_SIZE`

If the cluster is already running an older Talos image schematic, upgrading or
reinstalling the nodes is still required in addition to `make apply`, because
system extensions come from the Talos image.

If you change `WORKER_DATA_DISK_GIB`, the new worker disk size only takes effect
for newly created qcow2 images. Rebuild from scratch or remove the existing
worker disk images before expecting the new capacity to appear in Talos.

When Longhorn is installed later, set its default data path to
`/var/mnt/longhorn` so it uses the Talos-managed user volume instead of the
legacy `/var/lib/longhorn` path.

The Longhorn namespace must opt into privileged Pod Security admission. In Git,
label the namespace at least with:

```yaml
pod-security.kubernetes.io/enforce: privileged
```

If you also set Pod Security `audit` and `warn` labels for consistency, keep
them at `privileged` as well.

## What the scripts generate

Runtime state is written under `.state/`:

- `.state/assets/`: Talos ISO with the Tailscale extension
- `.state/disks/`: QEMU node disks
- `.state/talos/generated/`: generated per-node Talos configs for control
  planes and workers
- `.state/kubeconfig/config`: Kubernetes client config
- `.state/argocd/`: downloaded Argo CD install manifest and rendered root
  Application
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
  - TS_ACCEPT_DNS=false
  - TS_STATE_DIR=/var/lib/tailscale
  - TS_EXTRA_ARGS=--reset
```

They also include a Talos `ResolverConfig` so host DNS can forward MagicDNS
queries to Tailscale while still keeping a public resolver available:

```yaml
apiVersion: v1alpha1
kind: ResolverConfig
nameservers:
  - address: 100.100.100.100
  - address: 9.9.9.9
  - address: 1.1.1.1
  - address: 8.8.8.8
searchDomains:
  domains:
    - tail4d7760.ts.net
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

Generated worker configs also include a Longhorn-specific kubelet bind mount and
Talos user volume declaration:

```yaml
machine:
  kubelet:
    extraMounts:
      - destination: /var/mnt/longhorn
        type: bind
        source: /var/mnt/longhorn
        options:
          - bind
          - rshared
          - rw
---
apiVersion: v1alpha1
kind: UserVolumeConfig
name: longhorn
provisioning:
  diskSelector:
    match: disk.dev_path == "/dev/vdb"
  maxSize: 16GiB
```

## Validation checklist

Run:

```bash
make validate
```

The validation covers:

- Talos API access through Tailscale hostnames
- `ext-tailscale` service status on every node
- etcd membership and health on the control-plane nodes
- Kubernetes node readiness and InternalIP selection
- A small workload scheduled by normal Kubernetes rules and service
  reachability check using a temporary PodSecurity-compliant curl pod

To audit recurring Talos log noise without dumping raw logs, run:

```bash
make logs-audit
```

This summarizes known patterns per node and labels them as:

- `historical`: present in the recent log history, but not in the most recent window
- `recurring`: still appearing in the recent log window and worth attention

To inspect Tailscale extension logs during bootstrap/debugging:

```bash
make logs-tailscale
make logs-tailscale-cp1
make logs-tailscale-cp2
make logs-tailscale-cp3
```

Known acceptable transient messages:

- During early bootstrap, Kubernetes nodes may be `NotReady` for a short time
  while flannel and kube-proxy come up.

Known avoidable log noise:

- If the Tailscale extension is configured with `TS_ACCEPT_DNS=true`, it will
  try to rewrite `/etc/resolv.conf` and log read-only filesystem errors on
  Talos. This repo defaults `TAILSCALE_ACCEPT_DNS=false` and relies on Talos
  `ResolverConfig` instead.

For additional manual inspection:

```bash
export TALOSCONFIG=.state/talos/generated/talosconfig
export KUBECONFIG=.state/kubeconfig/config

talosctl --nodes talos-ts-cp1,talos-ts-cp2,talos-ts-cp3,talos-ts-worker1,talos-ts-worker2,talos-ts-worker3 service ext-tailscale
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
