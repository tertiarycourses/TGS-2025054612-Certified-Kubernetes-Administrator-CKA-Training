# Step 6 — Reclaim behavior

```bash
kubectl delete pod web
kubectl delete pvc pvc-host
kubectl get pv pv-host
```

**Expected result:** the PV is `Released`, **not** `Available` — and a new PVC will *not*
bind to it, even an identical one. With `Retain` the data is deliberately kept and the
volume quarantined for an admin to inspect.

Make it reusable by clearing the stale claim reference:

```bash
kubectl patch pv pv-host --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'
kubectl get pv pv-host
```

**Expected result:** `Available` again. With `persistentVolumeReclaimPolicy: Delete` the PV
(and its data) would have been removed instead — which is the default for dynamically
provisioned volumes in Lab 24.
