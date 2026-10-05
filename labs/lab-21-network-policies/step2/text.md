# Step 2 — Baseline: everything allowed

```bash
kubectl -n netpol exec client-ok  -- curl -s -o /dev/null -w "%{http_code}\n" http://server
kubectl -n netpol exec client-bad -- curl -s -o /dev/null -w "%{http_code}\n" http://server
```

**Expected result:** `200` from both.

With no policy in the namespace, all pod-to-pod traffic is allowed — Kubernetes is
allow-by-default until the first policy selects a pod.
