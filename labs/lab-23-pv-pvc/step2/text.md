# Step 2 — Create a PV

Note the heredoc below is unquoted (`<<EOF`, not `<<'EOF'`) so the shell substitutes
`$TARGET` from Step 1 as the PV is created — a PV's `nodeAffinity` is **immutable
afterwards**, so it has to be right the first time:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-host
spec:
  capacity: { storage: 1Gi }
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath: { path: /mnt/data }
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: ["$TARGET"]
EOF
kubectl get pv pv-host
kubectl get pv pv-host -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values}{"\n"}'
```

**Expected result:** the PV is `Available` with capacity `1Gi`, `RWO`, reclaim policy
`Retain`, and its node affinity names your worker.

> **Why node affinity on a local volume?** Without it the scheduler may place the pod on a
> node where `/mnt/data` does not exist — the mount then silently succeeds against an empty
> directory. This is the same mechanism `local` volumes use, and the reason `hostPath` is
> unsuitable for real workloads.

Access modes:
- **ReadWriteOnce (RWO)** — one node, read-write
- **ReadOnlyMany (ROX)** — many nodes, read-only
- **ReadWriteMany (RWX)** — many nodes, read-write (needs NFS/CephFS-class storage)
- **ReadWriteOncePod (RWOP)** — one pod, read-write

Reclaim policies:
- **Retain** — keep data after PVC deletion (manual cleanup)
- **Delete** — remove the volume (dynamic provisioning default)
- **Recycle** — deprecated
