---
id: TASK-21
title: Deploy Grafana LGTM observability stack
status: To Do
assignee:
  - '@Codex'
created_date: '2026-04-23 14:32'
updated_date: '2026-04-23 14:35'
labels:
  - observability
  - metrics
  - logs
  - traces
  - grafana
  - prometheus
  - loki
  - tempo
  - alloy
  - gitops
dependencies:
  - TASK-4
  - TASK-5
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Deploy an initial Grafana-native LGTM observability stack for cluster metrics, logs, and traces. Recommended baseline is kube-prometheus-stack for Prometheus metrics and Grafana, Loki for logs, Tempo for traces, and Grafana Alloy for Kubernetes workload log collection and OTLP trace forwarding. Keep the first pass local-cluster friendly: pinned Helm charts through GitOps, Longhorn-backed persistence where useful, single-binary/local modes where appropriate, and Kubernetes workload logs before attempting Talos host log collection.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Prometheus/Grafana, Loki, Tempo, and Grafana Alloy are installed through Argo CD or the existing GitOps root with pinned chart or manifest versions.
- [ ] #2 Persistent storage requirements are documented and use Longhorn where persistence is enabled for Prometheus, Grafana, Loki, or Tempo.
- [ ] #3 Grafana is reachable through the documented local/Tailscale access path and has initial credentials handled through the chosen secret mechanism.
- [ ] #4 Grafana datasources for Prometheus, Loki, and Tempo are provisioned declaratively.
- [ ] #5 Cluster node, pod, and Kubernetes control-plane metrics are visible in Prometheus/Grafana.
- [ ] #6 Kubernetes workload logs from at least kube-system and one platform namespace are collected by Grafana Alloy and queryable in Grafana Explore through Loki.
- [ ] #7 A documented OTLP trace ingestion path sends sample traces through Grafana Alloy to Tempo and makes them queryable from Grafana.
- [ ] #8 README documents sync, validation, access, credential recovery, storage choices, and basic troubleshooting.
<!-- AC:END -->
