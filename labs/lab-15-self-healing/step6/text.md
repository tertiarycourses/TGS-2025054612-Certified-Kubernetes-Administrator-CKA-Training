# Step 6 — Cleanup

```bash
kubectl delete pod live-demo ready-demo
kubectl delete deploy rs-demo
kubectl -n kube-system delete ds log-agent
kubectl delete statefulset web-ss
kubectl delete svc web-headless
kubectl delete pod dnstest --ignore-not-found
```

**Expected result:** everything removed. Deleting a StatefulSet leaves any PVCs behind by
design — there are none here, but remember it for Labs 23-25.
