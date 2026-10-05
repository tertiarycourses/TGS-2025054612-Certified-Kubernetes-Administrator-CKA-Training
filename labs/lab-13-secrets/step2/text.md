# Step 2 — Consume as env vars

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: sec-env }
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh","-c","echo user=$DB_USER pw=$DB_PASS; sleep 3600"]
    env:
    - name: DB_USER
      valueFrom: { secretKeyRef: { name: db-creds, key: username } }
    - name: DB_PASS
      valueFrom: { secretKeyRef: { name: db-creds, key: password } }
EOF
kubectl wait --for=condition=Ready pod/sec-env --timeout=60s
kubectl logs sec-env
```

**Expected result:** `user=admin pw=S3cure!Pw`.

Note what that implies: the value is now in the container's environment, visible to
`kubectl describe pod`-level tooling, crash dumps and child processes. Mounted files
(Step 3) are the safer option.
