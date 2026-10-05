# Lab 29 — Monitor Cluster and Application Usage

In this lab you install metrics-server, use `kubectl top`, then install the kube-prometheus-stack via Helm for the full Prometheus + Grafana experience.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Install metrics-server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deploy metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s
until kubectl top nodes > /dev/null 2>&1; do echo "waiting for the Metrics API..."; sleep 10; done
echo "metrics available"
```

**Expected result:** the rollout completes, and after up to a minute of
`waiting for the Metrics API...` you get `metrics available`. Until that first scrape lands,
`kubectl top` fails with `error: Metrics API not available` — the API registering, not a
broken install.

`--kubelet-insecure-tls` is required wherever the kubelet serves a self-signed certificate,
which includes this playground; without it metrics-server logs
`x509: cannot validate certificate` and never becomes ready.

---

## Step 2 — kubectl top

```bash
kubectl top nodes
kubectl top pods -A
kubectl top pods -A --sort-by=cpu | head
kubectl top pods -A --sort-by=memory | head
```

**Expected result:** CPU in millicores and memory in Mi for both nodes, then per-pod
figures. The control-plane components (`kube-apiserver`, `etcd`) dominate the sorted lists —
on a 1-CPU node they routinely use most of it.

```bash
kubectl top pods -A --sort-by=cpu | head -5
```

> `kubectl top` shows **live usage** from metrics-server, which keeps only a short window in
> memory. It cannot show history, and it is not what HPA uses for custom metrics — that is
> the gap Prometheus fills.

---

## Step 3 — Events

```bash
kubectl get events --sort-by=.lastTimestamp -A | tail -20
kubectl get events --field-selector type=Warning -A
```

**Expected result:** recent events, newest last, and a filtered list of warnings —
`FailedScheduling`, `Unhealthy` or image-pull failures from earlier labs.

> Events are kept in etcd for **one hour** by default (`--event-ttl`), so they are a
> short-term debugging aid, not an audit log. `kubectl get events` is namespaced: pass `-A`
> or you will miss the event you are looking for.

---

## Step 4 — Container-level stats via cAdvisor (reference)

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl get --raw "/api/v1/nodes/$NODE/proxy/stats/summary" | head -50
```

**Expected result:** a large JSON document beginning with the node's own CPU and memory
usage, followed by a `pods` array with per-container numbers.

This is cAdvisor inside the kubelet, and it is the *source* for everything else:
metrics-server summarises it for `kubectl top` and HPA, and Prometheus scrapes the related
`/metrics/cadvisor` endpoint. Useful when `kubectl top` is unavailable:

```bash
kubectl get --raw "/api/v1/nodes/$NODE/proxy/stats/summary" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["node"]["nodeName"], d["node"]["cpu"]["usageNanoCores"])'
```

**Expected result:** the node name and a raw nanocore figure.

---

## Step 5 — kube-prometheus-stack (reference — do not run it here)

The de-facto open-source monitoring deployment is the `kube-prometheus-stack` chart. **It
will not run on this playground**, and it is worth knowing why before you try it in the
exam environment or on a laptop cluster.

The chart installs roughly ten workloads: the Prometheus Operator, a Prometheus server
(1 Gi+ of memory), Alertmanager, Grafana, kube-state-metrics and a node-exporter
DaemonSet. The two nodes here have **1 CPU each**, most of which the control plane is
already using — pods would sit `Pending` with `Insufficient cpu`, as you can confirm with
the `kubectl top nodes` output from Step 2.

For reference, this is the install on a cluster that can take it (4+ CPUs, 8 Gi+ RAM):

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kp prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=admin
kubectl -n monitoring rollout status deploy/kp-grafana --timeout=300s
kubectl -n monitoring port-forward svc/kp-grafana 3000:80
```

Grafana then answers on port 3000 (`admin` / `admin`), and on KillerCoda you would open it
through the traffic panel.

**What to take away instead:** metrics-server gives you *live* usage for `kubectl top` and
HPA and keeps no history; Prometheus scrapes and stores time series so you can alert and
look backwards. They solve different problems and production clusters run both.

If you want a scrape-and-query experience on a small cluster, install Prometheus alone —
still around 512 Mi, so expect it to be slow here:

```bash
# reference only
helm install prom prometheus-community/prometheus \
  --namespace monitoring --create-namespace \
  --set alertmanager.enabled=false \
  --set prometheus-pushgateway.enabled=false
```

---

## Step 6 — PromQL you should recognise

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

---

## Step 7 — Cleanup

```bash
# only if you installed something in Step 5 on a larger cluster
helm -n monitoring uninstall kp --ignore-not-found 2>/dev/null || true
kubectl delete ns monitoring --ignore-not-found
```

**Expected result:** nothing to remove on this playground, since Step 5 is reference only.
Leave metrics-server installed — Lab 14's HPA needs it.

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — metrics-server | `metrics available` after the wait loop |
| Step 2 — top | CPU/memory for both nodes and pods; control plane dominates |
| Step 3 — events | recent events plus a warnings-only list |
| Step 4 — cAdvisor | JSON summary; the helper prints the node name and nanocores |
| Step 5 — Prometheus | understood as reference; not installed here |
| Step 6 — PromQL | you can say what each query returns and why counters need `rate()` |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `error: Metrics API not available` | The first scrape has not landed. Use the wait loop in Step 1. |
| metrics-server never Ready | Missing `--kubelet-insecure-tls`; see its logs for `x509`. |
| `kubectl top pods` empty for a namespace | The pods are too new — metrics appear after a scrape interval (~15s). |
| kube-prometheus-stack pods `Pending` | Expected on 1 CPU: `Insufficient cpu`. Step 5 is reference only. |
| `kubectl get events` shows nothing old | Events expire after ~1 hour by default. |
| `port-forward` to Grafana refuses | The pod is not Ready; on this playground it never will be. |

---

## What you learned
- metrics-server feeds `kubectl top` and HPA.
- Events for short-term audit, Prometheus for long-term metrics.
- The kube-prometheus-stack is the de-facto OSS monitoring deploy.
