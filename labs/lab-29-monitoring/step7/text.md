# Step 7 — Cleanup

```bash
# only if you installed something in Step 5 on a larger cluster
helm -n monitoring uninstall kp --ignore-not-found 2>/dev/null || true
kubectl delete ns monitoring --ignore-not-found
```

**Expected result:** nothing to remove on this playground, since Step 5 is reference only.
Leave metrics-server installed — Lab 14's HPA needs it.
