---
id: TASK-25.6
title: Automate creation of a local Headscale base qcow2 image
status: Done
assignee:
  - '@Codex'
created_date: '2026-04-29 18:36'
updated_date: '2026-04-29 18:59'
labels:
  - networking
  - headscale
  - vm
  - image-build
  - automation
dependencies: []
parent_task_id: TASK-25
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add repo-managed automation for producing a reusable Headscale base qcow2 image from an official Debian or Ubuntu cloud image. The output should match Headscale's officially supported package-based installation model and integrate cleanly with the existing local Headscale VM lifecycle, while keeping the resulting image shape portable to later remote/cloud deployment targets.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A repo-managed workflow can download or consume an official Debian/Ubuntu cloud base image and produce a reusable Headscale qcow2 image for local VM use.
- [x] #2 The automated build installs Headscale using the official Debian/Ubuntu package path, writes the required service/config bootstrap files, and enables the service for first boot.
- [x] #3 The workflow documents and enforces the required host-side build dependencies and input variables without assuming Headscale is permanently local-only.
- [x] #4 The resulting image-build workflow is wired into the repo's documented developer flow and is covered by local script-behavior tests where feasible.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Replace the current `virt-customize` image-build direction with a Packer-based workflow using the official QEMU builder so the same image pipeline can later be adapted for Hetzner.
2. Add repo-managed Packer template(s) plus supporting cloud-init or shell provisioning assets to build a Debian 12-based Headscale image that installs the official Headscale Debian package, writes `/etc/headscale/config.yaml`, and enables `headscale.service`.
3. Wire the Packer workflow into the repo through a new `make headscale-image` flow and the necessary `.env`/default variables, keeping the produced local qcow2 compatible with the existing Headscale support-VM lifecycle.
4. Update documentation to explain the new Packer prerequisites and why the workflow is shaped for both local qcow2 output now and Hetzner-oriented image reuse later.
5. Update local harness coverage to validate the new Packer-driven script flow and remove or replace assumptions specific to the discarded `virt-customize` path.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Replaced the superseded `virt-customize` path with a Packer-based workflow so the same image-build pipeline can later be reused for Hetzner-oriented Headscale deployment.

Implemented `scripts/build-headscale-image.sh`, `packer/headscale.pkr.hcl`, `config/headscale/config.yaml.tpl`, and NoCloud seed templates in `config/headscale/user-data.tpl` and `config/headscale/meta-data.tpl`.

The workflow now downloads the Debian 12 generic cloud qcow2 image and the official Headscale Debian package, renders image-specific config and seed files under `.state/headscale/packer/`, runs `packer init` plus `packer build`, and copies the resulting qcow2 artifact into `.state/headscale/headscale-base.qcow2` for the existing local Headscale VM lifecycle.

Repo defaults and documentation were updated so the image build is parameterized through `.env` values such as `HEADSCALE_BASE_IMAGE_URL`, `HEADSCALE_DEB_URL`, `HEADSCALE_SERVER_URL`, `HEADSCALE_LISTEN_ADDR`, `HEADSCALE_BASE_DOMAIN`, and image identity values. This keeps the image portable instead of hard-coding a permanently local-only deployment shape.

The Packer provisioning flow avoids apt lock races by waiting for `cloud-init status --wait` and keeps the seed responsible only for SSH/bootstrap access. It installs the official Headscale `.deb`, writes `/etc/headscale/config.yaml`, enables `headscale.service`, validates the config with `headscale configtest`, and cleans machine identity state before shutdown.

Validation status:
- `bash -n` passed for the updated scripts.
- `bash tests/script-behavior.sh` passed with fake-command coverage for the Packer image-build flow.
- A real `make --no-print-directory headscale-image` run completed successfully, including Packer plugin install, Debian qcow2 download, Headscale package download, guest boot, SSH provisioning, Headscale install/config validation, and qcow2 artifact creation at `.state/headscale/headscale-base.qcow2`.
- `qemu-img info .state/headscale/headscale-base.qcow2` confirmed a valid qcow2 artifact (40G virtual size, non-corrupt).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Replaced the abandoned `virt-customize` path with a Packer-based Headscale image pipeline. The repo now builds a reusable Debian 12 qcow2 image by downloading an official cloud base image, installing the official Headscale Debian package inside a Packer/QEMU build, rendering the required config and NoCloud seed files, and exporting the finished artifact to `.state/headscale/headscale-base.qcow2` for the existing local support-VM lifecycle. Updated `.env` defaults, Makefile, README, and script-behavior tests to document and exercise the new flow.

Verified the change with `bash -n`, `bash tests/script-behavior.sh`, and a real `make --no-print-directory headscale-image` run. The live build successfully completed end to end and produced a valid qcow2 artifact confirmed by `qemu-img info`.
<!-- SECTION:FINAL_SUMMARY:END -->
