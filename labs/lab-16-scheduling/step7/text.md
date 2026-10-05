# Step 7 — Cleanup

```bash
kubectl delete pod ssd-pod affinity-pod sized tolerant notol nowhere --ignore-not-found
kubectl delete deploy spread --ignore-not-found
kubectl label node $NODE disktype- tier-
kubectl taint node $NODE workload- 2>/dev/null || true
kubectl get nodes -L disktype,tier
kubectl describe node $NODE | grep -i taints
```

**Expected result:** the `disktype`/`tier` columns are empty and the worker's `Taints:` line
reads `<none>`. Leaving a stray taint behind is the most common way to break the *next*
lab.
