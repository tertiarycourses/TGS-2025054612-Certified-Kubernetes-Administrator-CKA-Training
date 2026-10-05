# Step 2 — Install local-path-provisioner

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.37/deploy/local-path-storage.yaml
kubectl -n local-path-storage rollout status deploy/local-path-provisioner --timeout=180s
kubectl get storageclass
```

**Expected result:** a StorageClass named `local-path` with provisioner
`rancher.io/local-path` and **`VOLUMEBINDINGMODE: WaitForFirstConsumer`** — remember that
column, it decides the behaviour in Step 4.

> Pinned to `v0.0.37` rather than `master`: a moving branch has broken this lab between
> course runs before.
