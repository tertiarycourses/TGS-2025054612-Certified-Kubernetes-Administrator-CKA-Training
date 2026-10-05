# Step 6 — Pause and resume

```bash
kubectl rollout pause deploy/web
kubectl set image deploy/web nginx=nginx:1.27
kubectl set resources deploy/web --limits=cpu=200m,memory=256Mi
kubectl rollout resume deploy/web
kubectl rollout status deploy/web
```

**Expected result:** nothing happens while paused — no new ReplicaSet, no new pods. The
moment you `resume`, **one** rollout applies both the image and the resource change
together.

Check it only cost you one revision:

```bash
kubectl rollout history deploy/web | tail -3
kubectl get rs -l app=web
```

**Expected result:** a single new revision, and one ReplicaSet with non-zero replicas while
the older ones sit at `0` — kept for rollback.
