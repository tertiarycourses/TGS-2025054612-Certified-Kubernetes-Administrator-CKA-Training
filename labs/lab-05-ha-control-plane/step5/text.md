# Step 5 — Lose the data

```bash
kubectl delete namespace demo-backup
kubectl get ns | grep demo-backup || echo "demo-backup is gone"
```

Everything from Step 3 is now out of etcd.
