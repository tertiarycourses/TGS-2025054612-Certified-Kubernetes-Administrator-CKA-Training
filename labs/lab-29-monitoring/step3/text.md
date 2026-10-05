# Step 3 — Events

```bash
kubectl get events --sort-by=.lastTimestamp -A | tail -20
kubectl get events --field-selector type=Warning -A
```

**Expected result:** recent events, newest last, and a filtered list of warnings —
`FailedScheduling`, `Unhealthy` or image-pull failures from earlier labs.

> Events are kept in etcd for **one hour** by default (`--event-ttl`), so they are a
> short-term debugging aid, not an audit log. `kubectl get events` is namespaced: pass `-A`
> or you will miss the event you are looking for.
