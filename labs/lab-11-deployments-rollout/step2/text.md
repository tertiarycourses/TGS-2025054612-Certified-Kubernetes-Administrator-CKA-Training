# Step 2 — Inspect the strategy

```bash
kubectl get deploy web -o yaml | grep -A5 strategy
```

**Expected result:**

```yaml
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
```

With four replicas that means at most 5 pods during the rollout (`+25%`) and at least 3
serving (`-25%`) — Kubernetes rounds surge up and unavailability down.
