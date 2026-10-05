# Step 3 — Create a PVC

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: pvc-host }
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: manual
  resources: { requests: { storage: 500Mi } }
EOF
kubectl get pvc pvc-host
kubectl get pv pv-host
```

**Expected result:** the PVC is `Bound` to `pv-host`, and the PV's status flips from
`Available` to `Bound` with `CLAIM default/pvc-host`.

Binding needs **all** of: the same `storageClassName`, a compatible access mode, and a PV
at least as large as the request. Note the PVC asked for `500Mi` and got the whole `1Gi`
volume — static PVs are never split.
