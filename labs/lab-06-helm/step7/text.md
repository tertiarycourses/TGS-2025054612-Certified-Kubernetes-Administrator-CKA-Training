# Step 7 — Uninstall

```bash
helm -n web uninstall web
kubectl -n web get all
kubectl delete ns web
```

**Expected result:** `release "web" uninstalled`, then `No resources found` — uninstall
removes everything the release created, but **not** the namespace, which `helm` only made
because you passed `--create-namespace`.
