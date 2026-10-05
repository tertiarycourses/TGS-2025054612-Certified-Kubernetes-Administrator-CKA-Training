# Step 1 — Baseline

```bash
kubectl get nodes
kubectl describe node node01 | grep -E "Conditions|Taints" -A6
```

**Expected result:** `node01` is `Ready`, with `MemoryPressure`, `DiskPressure` and
`PIDPressure` all `False` and no taints.

Those are the five conditions the kubelet reports: `Ready`, `MemoryPressure`,
`DiskPressure`, `PIDPressure`, `NetworkUnavailable`. "False" is the healthy value for the
pressure conditions — a `True` there is the kubelet asking for help.
