# Step 1 — Check existing storage classes

```bash
kubectl get storageclass
```

**Expected result:** on a plain `kubeadm` cluster, `No resources found` — there is no
dynamic provisioning until you add a provisioner. If a `local-path` class is already listed
(some playground images ship one), skip Step 2.
