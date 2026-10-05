# Step 1 — emptyDir (scratch space, pod lifetime)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: scratch }
spec:
  containers:
  - name: writer
    image: busybox
    command: ["sh","-c","echo hello > /data/file; sleep 3600"]
    volumeMounts: [{ name: tmp, mountPath: /data }]
  - name: reader
    image: busybox
    command: ["sh","-c","cat /data/file; sleep 3600"]
    volumeMounts: [{ name: tmp, mountPath: /data }]
  volumes:
  - name: tmp
    emptyDir: {}
EOF
kubectl wait --for=condition=Ready pod/scratch --timeout=60s
kubectl logs scratch -c reader
```

**Expected result:** `hello` — written by the `writer` container, read by `reader` through
the shared `emptyDir`.

```bash
kubectl exec scratch -c reader -- df -h /data | tail -1
```

**Expected result:** the mount is backed by the node's disk (an `overlay` or `/dev/...`
line). `emptyDir: {}` lives on disk; add `medium: Memory` to make it tmpfs. Either way it
is created when the pod starts and **deleted with the pod** — scratch space, never
storage.
