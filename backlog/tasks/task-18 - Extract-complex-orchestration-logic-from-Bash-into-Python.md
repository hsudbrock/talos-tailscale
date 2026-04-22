---
id: TASK-18
title: Extract complex orchestration logic from Bash into Python
status: To Do
assignee:
  - '@Codex'
created_date: '2026-04-22 21:40'
labels:
  - tooling
  - python
  - bash
  - refactor
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Move the structured-data and decision-heavy parts of the local cluster harness into Python while keeping the current Makefile and thin shell entrypoints. The goal is not a rewrite. The goal is to improve correctness, testability, and maintainability in the areas where Bash is a poor fit, starting with Talos config generation and local validation logic.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Decision documents which scripts stay in Bash and which logic moves to Python first.
- [ ] #2 Talos config generation logic is implemented in Python behind the existing make/scripts entrypoints.
- [ ] #3 Validation or audit logic with structured parsing is implemented in Python where it meaningfully reduces shell complexity.
- [ ] #4 Make targets and operator UX remain stable or change only with explicit README updates.
- [ ] #5 Tests cover the new Python logic and keep the current no-secrets local test workflow.
- [ ] #6 README documents the Python runtime/dependency expectations for contributors.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Identify the highest-complexity shell scripts and split thin orchestration from real logic.
2. Introduce Python modules for config rendering and structured validation while preserving current script entrypoints.
3. Keep VM lifecycle glue in Bash unless Python materially improves it.
4. Update tests and documentation incrementally instead of doing a repository-wide rewrite.
<!-- SECTION:PLAN:END -->
