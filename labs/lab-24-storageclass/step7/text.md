# Step 7 — Cleanup

```bash
kubectl delete statefulset db
kubectl delete svc db-headless
kubectl delete pod user --ignore-not-found
kubectl delete pvc -l app=db
kubectl delete pvc data-pvc
kubectl get pvc,pv
```

**Expected result:** no PVCs remain, and the PVs disappear with them — the dynamic class
uses reclaim policy `Delete`, so the volume *and its data* go away. Contrast Lab 23, where
`Retain` kept both.

> **PVCs from `volumeClaimTemplates` are never auto-deleted** when you remove the
> StatefulSet: Kubernetes assumes the data matters more than the controller. Deleting them
> is a deliberate act, which is exactly why this step exists.
