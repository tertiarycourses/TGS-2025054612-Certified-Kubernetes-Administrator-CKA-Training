# Step 2 — Use the new resource

```bash
kubectl api-resources | grep widgets
cat <<'EOF' | kubectl apply -f -
apiVersion: training.example.com/v1
kind: Widget
metadata:
  name: blue-widget
spec:
  color: blue
  size: 7
EOF
kubectl get widgets
kubectl describe widget blue-widget
```

**Expected result:** `api-resources` lists `widgets` with short name `wg`, and
`kubectl get widgets` shows `blue-widget`. Prove the schema is enforced — this must be
**rejected**:

```bash
kubectl apply -f - <<'EOF'
apiVersion: training.example.com/v1
kind: Widget
metadata:
  name: too-big
spec:
  color: red
  size: 500
EOF
```

**Expected result:** `spec.size: Invalid value: 500: spec.size in body should be less than
or equal to 100` — the API server validated your custom object against the CRD's schema.

The CRD gives you storage and validation, but **no controller is reconciling it** — `kubectl get widgets` reads from etcd, nothing else happens. That's the missing operator piece.
