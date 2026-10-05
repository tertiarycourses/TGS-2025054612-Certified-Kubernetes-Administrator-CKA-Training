# Step 2 — kubectl top

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
