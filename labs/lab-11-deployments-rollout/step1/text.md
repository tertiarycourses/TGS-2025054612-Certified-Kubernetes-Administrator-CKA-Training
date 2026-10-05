# Step 1 — Create the Deployment

```bash
kubectl create deployment web --image=nginx:1.25 --replicas=4
kubectl rollout status deploy/web
kubectl get pods -l app=web -o wide
```

**Expected result:** `deployment "web" successfully rolled out` and four `Running` pods. On
a 1-CPU playground this takes a moment; the control-plane node is tainted, so all four land
on `node01`.
