SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

.PHONY: help env image configs start apply bootstrap validate stop clean reset test-local

help:
	@printf 'Talos over Tailscale local test targets:\n\n'
	@printf '  make env        Create .env from the example if it does not exist\n'
	@printf '  make image      Build/download Talos ISO with the Tailscale extension\n'
	@printf '  make configs    Generate Talos configs from .env\n'
	@printf '  make start      Start the three isolated QEMU VMs\n'
	@printf '  make apply      Apply Talos machine configs through localhost forwards\n'
	@printf '  make bootstrap  Bootstrap etcd/Kubernetes and fetch kubeconfig\n'
	@printf '  make validate   Validate Talos, Kubernetes, etcd, and smoke workload\n'
	@printf '  make stop       Stop the QEMU VMs\n'
	@printf '  make clean      Remove generated .state after stopping VMs\n'
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

stop:
	scripts/stop-vms.sh

clean: stop
	rm -rf .state

reset: clean

test-local:
	bash -n scripts/lib.sh scripts/prepare-image.sh scripts/generate-configs.sh scripts/start-vms.sh scripts/apply-configs.sh scripts/bootstrap.sh scripts/validate.sh scripts/stop-vms.sh
