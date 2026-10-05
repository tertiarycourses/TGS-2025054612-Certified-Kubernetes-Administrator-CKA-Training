# Step 3 — Curl the nginx pod directly

```bash
kubectl exec client -- curl -s -o /dev/null -w "%{http_code}\n" http://$SERVER_IP
```

**Expected result:** `200` — straight to the pod IP, with no Service in the path.
