# Step 5 — Stop the load and watch scale-down

Ctrl-C the load generator (or open a second tab), then:

```bash
kubectl delete pod load --ignore-not-found
kubectl get hpa -w
```

**Expected result:** `TARGETS` drops to `0%/50%` within a minute, but `REPLICAS` stays high
for about **5 minutes** before returning to `1`.

That delay is the scale-down **stabilisation window**
(`--horizontal-pod-autoscaler-downscale-stabilization`, default 300s): the HPA takes the
highest recommendation from the last 5 minutes so a brief dip cannot cause flapping.
Scale-up has no such window, which is why up is fast and down is slow. Press Ctrl-C when
you have seen `REPLICAS 1`.
