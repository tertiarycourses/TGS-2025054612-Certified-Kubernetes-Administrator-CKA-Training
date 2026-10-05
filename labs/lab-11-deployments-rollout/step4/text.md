# Step 4 — Cause a bad rollout

```bash
kubectl set image deploy/web nginx=nginx:doesnotexist
kubectl rollout status deploy/web --timeout=30s
kubectl get pods -l app=web
```

**Expected result:** `rollout status` gives up with
`error: timed out waiting for the condition`, and `get pods` shows one new pod in
`ImagePullBackOff` or `ErrImagePull` while **three old pods keep Running**.

That is `maxUnavailable: 25%` protecting you: the Deployment refuses to remove healthy
replicas until the new ones are ready, so a bad image degrades a rollout instead of taking
the app down.

```bash
kubectl rollout history deploy/web
kubectl describe deploy web | grep -A3 Conditions
```

**Expected result:** a third revision exists, and the conditions report
`ProgressDeadlineExceeded`.
