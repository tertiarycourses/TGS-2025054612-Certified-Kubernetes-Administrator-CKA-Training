# Step 5 — Lose the data

```bash
kubectl delete namespace demo-backup
kubectl get ns | grep demo-backup || echo "demo-backup is gone"
```

**Expected result:** `demo-backup is gone`. Everything you created in Step 3 no longer
exists in etcd.
