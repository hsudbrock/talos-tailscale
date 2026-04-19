SHELL := /usr/bin/env bash
STATE_DIR ?= .state
KUBECONFIG ?= $(STATE_DIR)/kubeconfig/config

.DEFAULT_GOAL := help

.PHONY: help env image configs start apply bootstrap validate k9s stop clean clean-disks reset test test-local vnc-cp1 vnc-cp2 vnc-cp3 vnc-worker1 vnc-worker2 vnc-worker3 logs-tailscale logs-tailscale-cp1 logs-tailscale-cp2 logs-tailscale-cp3 logs-tailscale-worker1 logs-tailscale-worker2 logs-tailscale-worker3

help:
	@printf 'Talos over Tailscale local test targets:\n\n'
	@printf '  make env        Create .env from the example if it does not exist\n'
	@printf '  make image      Build/download Talos ISO with the Tailscale extension\n'
	@printf '  make configs    Generate Talos configs from .env\n'
	@printf '  make start      Start the isolated QEMU VMs\n'
	@printf '  make apply      Apply Talos machine configs through localhost forwards\n'
	@printf '  make bootstrap  Bootstrap etcd/Kubernetes and fetch kubeconfig\n'
	@printf '  make validate   Validate Talos, Kubernetes, etcd, and smoke workload\n'
	@printf '  make k9s        Open k9s with the generated kubeconfig\n'
	@printf '  make stop       Stop the QEMU VMs\n'
	@printf '  make clean      Remove generated .state after stopping VMs\n'
	@printf '  make clean-disks Stop VMs and remove only VM disks\n'
	@printf '  make test       Run local non-secret validation checks\n'
	@printf '  make vnc-cp1    Open talos-ts-cp1 VNC console with TigerVNC\n'
	@printf '  make logs-tailscale Show ext-tailscale logs from all nodes\n'
	@printf '\nTypical flow:\n'
	@printf '  make env\n'
	@printf '  $$EDITOR .env\n'
	@printf '  make image configs start apply bootstrap validate\n'

env:
	@if [[ -f .env ]]; then \
		echo ".env already exists"; \
	else \
		cp config/talos-tailnet.env.example .env; \
		echo "Created .env. Edit TS_AUTHKEY before continuing."; \
	fi

image:
	scripts/prepare-image.sh

configs:
	scripts/generate-configs.sh

start:
	scripts/start-vms.sh

apply:
	scripts/apply-configs.sh

bootstrap:
	scripts/bootstrap.sh

validate:
	scripts/validate.sh

k9s:
	@command -v k9s >/dev/null || { echo "missing k9s; install it before running this target" >&2; exit 1; }
	@[[ -f "$(KUBECONFIG)" ]] || { echo "missing $(KUBECONFIG); run make bootstrap first" >&2; exit 1; }
	KUBECONFIG="$(KUBECONFIG)" k9s

stop:
	scripts/stop-vms.sh

clean: stop
	rm -rf .state

clean-disks: stop
	rm -rf .state/disks

reset: clean

test: test-local

test-local:
	bash -n scripts/lib.sh scripts/prepare-image.sh scripts/generate-configs.sh scripts/start-vms.sh scripts/apply-configs.sh scripts/bootstrap.sh scripts/validate.sh scripts/stop-vms.sh
	bash tests/script-behavior.sh

vnc-cp1:
	xtigervncviewer -RemoteResize=0 127.0.0.1::5901

vnc-cp2:
	xtigervncviewer -RemoteResize=0 127.0.0.1::5902

vnc-cp3:
	xtigervncviewer -RemoteResize=0 127.0.0.1::5903

vnc-worker1:
	xtigervncviewer -RemoteResize=0 127.0.0.1::5904

vnc-worker2:
	xtigervncviewer -RemoteResize=0 127.0.0.1::5905

vnc-worker3:
	xtigervncviewer -RemoteResize=0 127.0.0.1::5906

logs-tailscale: logs-tailscale-cp1 logs-tailscale-cp2 logs-tailscale-cp3 logs-tailscale-worker1 logs-tailscale-worker2 logs-tailscale-worker3

logs-tailscale-cp1:
	@for attempt in {1..10}; do \
		talosctl --talosconfig .state/talos/generated/talosconfig --endpoints 127.0.0.1:50001 --nodes 127.0.0.1 logs ext-tailscale --tail 120 && exit 0; \
		echo "ext-tailscale logs for cp1 not ready yet; retrying ($$attempt/10)..." >&2; \
		sleep 2; \
	done; \
	exit 1

logs-tailscale-cp2:
	@for attempt in {1..10}; do \
		talosctl --talosconfig .state/talos/generated/talosconfig --endpoints 127.0.0.1:50002 --nodes 127.0.0.1 logs ext-tailscale --tail 120 && exit 0; \
		echo "ext-tailscale logs for cp2 not ready yet; retrying ($$attempt/10)..." >&2; \
		sleep 2; \
	done; \
	exit 1

logs-tailscale-cp3:
	@for attempt in {1..10}; do \
		talosctl --talosconfig .state/talos/generated/talosconfig --endpoints 127.0.0.1:50003 --nodes 127.0.0.1 logs ext-tailscale --tail 120 && exit 0; \
		echo "ext-tailscale logs for cp3 not ready yet; retrying ($$attempt/10)..." >&2; \
		sleep 2; \
	done; \
	exit 1

logs-tailscale-worker1:
	@for attempt in {1..10}; do \
		talosctl --talosconfig .state/talos/generated/talosconfig --endpoints 127.0.0.1:50004 --nodes 127.0.0.1 logs ext-tailscale --tail 120 && exit 0; \
		echo "ext-tailscale logs for worker1 not ready yet; retrying ($$attempt/10)..." >&2; \
		sleep 2; \
	done; \
	exit 1

logs-tailscale-worker2:
	@for attempt in {1..10}; do \
		talosctl --talosconfig .state/talos/generated/talosconfig --endpoints 127.0.0.1:50005 --nodes 127.0.0.1 logs ext-tailscale --tail 120 && exit 0; \
		echo "ext-tailscale logs for worker2 not ready yet; retrying ($$attempt/10)..." >&2; \
		sleep 2; \
	done; \
	exit 1

logs-tailscale-worker3:
	@for attempt in {1..10}; do \
		talosctl --talosconfig .state/talos/generated/talosconfig --endpoints 127.0.0.1:50006 --nodes 127.0.0.1 logs ext-tailscale --tail 120 && exit 0; \
		echo "ext-tailscale logs for worker3 not ready yet; retrying ($$attempt/10)..." >&2; \
		sleep 2; \
	done; \
	exit 1
