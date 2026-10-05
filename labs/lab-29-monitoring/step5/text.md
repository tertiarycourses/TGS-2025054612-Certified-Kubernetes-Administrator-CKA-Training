# Step 5 — kube-prometheus-stack (reference — do not run it here)

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
