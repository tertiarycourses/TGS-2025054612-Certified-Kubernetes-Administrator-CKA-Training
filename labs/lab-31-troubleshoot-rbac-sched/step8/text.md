# Step 8 — Cleanup

```bash
kubectl delete ns app
kubectl delete clusterrole node-reader
kubectl delete clusterrolebinding worker-nodes
kubectl taint node $NODE dedicated- 2>/dev/null || true
kubectl label node $NODE zone- 2>/dev/null || true
kubectl describe node $NODE | grep -i taints
```

**Expected result:** `Taints: <none>` on the worker. **Leaving the taint behind is the most
common way to break the next lab** — everything you create afterwards sits `Pending` for no
visible reason.
