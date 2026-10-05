# Step 1 — Install metrics-server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deploy metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s
```

Metrics are **not** available the moment the pod is ready — the API needs a scrape cycle
first. Wait for it instead of guessing:

```bash
until kubectl top nodes > /dev/null 2>&1; do echo "waiting for metrics..."; sleep 10; done
kubectl top nodes
kubectl top pods -A | head
```

**Expected result:** after up to a minute, `top nodes` prints CPU and memory for both nodes.
Until then it fails with `error: Metrics API not available` — that is the API registering,
not a broken install.

`--kubelet-insecure-tls` is needed in lab environments where the kubelet serves a
self-signed certificate; without it metrics-server logs `x509: cannot validate certificate`
and never becomes ready.
