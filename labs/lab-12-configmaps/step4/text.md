# Step 4 — Consume as a mounted file

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: file-demo }
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh","-c","cat /etc/cfg/app.properties; sleep 3600"]
    volumeMounts:
    - { name: cfg, mountPath: /etc/cfg }
  volumes:
  - name: cfg
    configMap: { name: app-properties }
EOF
kubectl wait --for=condition=Ready pod/file-demo --timeout=60s
kubectl logs file-demo
```

**Expected result:**

```text
log.level=INFO
cache.ttl=300
```

The ConfigMap key became a **file** at `/etc/cfg/app.properties`. Check what the mount
really looks like:

```bash
kubectl exec file-demo -- ls -l /etc/cfg/
```

**Expected result:** `app.properties` is a symlink into a `..data/` directory — that
indirection is how the kubelet swaps content atomically when the ConfigMap changes.
