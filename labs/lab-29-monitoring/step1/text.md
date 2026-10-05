# Step 1 — Install metrics-server

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
