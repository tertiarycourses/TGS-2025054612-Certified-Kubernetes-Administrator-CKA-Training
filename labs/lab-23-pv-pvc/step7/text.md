# Step 7 — Cleanup

```bash
kubectl delete pv pv-host
ssh $TARGET "sudo rm -rf /mnt/data"
```

**Expected result:** the PV is gone and the directory is removed **from the worker** — the
node where you created it.
