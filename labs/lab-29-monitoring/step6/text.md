# Step 6 — PromQL you should recognise

Even without Prometheus running, know what these ask for — the exam and every real
incident review use this vocabulary:

| Query | Answers |
|---|---|
| `node_cpu_seconds_total` | cumulative CPU seconds per node and mode (from node-exporter) |
| `rate(container_cpu_usage_seconds_total{namespace="default"}[1m])` | per-container CPU **per second**, averaged over a minute |
| `kube_pod_status_phase{phase="Pending"}` | pods stuck Pending (from kube-state-metrics) |
| `sum(kube_pod_container_resource_requests{resource="cpu"}) by (node)` | how much CPU is *requested* per node — the number the scheduler cares about |

Two habits worth keeping: counters like `..._total` are meaningless raw — always wrap them
in `rate()`; and `kube_state_metrics` describes **object state** while `cadvisor` describes
**resource usage**, so "is it Pending?" and "is it busy?" come from different sources.
