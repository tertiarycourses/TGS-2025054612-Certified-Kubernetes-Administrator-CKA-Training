# Step 5 — Pending due to resources

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: hungry, namespace: app }
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests: { cpu: "100", memory: "100Gi" }
EOF
kubectl -n app get pod hungry
kubectl -n app describe pod hungry | grep -A5 Events
```

**Expected result:** `Pending`, with
`0/2 nodes are available: 2 Insufficient cpu, 2 Insufficient memory`.

Requests of `cpu: "100"` (100 whole cores) and `100Gi` cannot be met, and the scheduler
reports **why, per node**. Requests — not limits — drive scheduling, so an over-requested
pod never starts even on an idle cluster.

Fix:

```bash
kubectl -n app delete pod hungry
```
