# Step 3 — Consume as environment variables

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: env-demo }
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh","-c","env | grep APP_; sleep 3600"]
    envFrom:
    - configMapRef: { name: app-config }
EOF
kubectl wait --for=condition=Ready pod/env-demo --timeout=60s
kubectl logs env-demo
```

**Expected result:**

```text
APP_ENV=prod
APP_TIER=backend
```

`envFrom` imported every key at once. Use `env:` with `configMapKeyRef` when you need one
key, or a different variable name.
