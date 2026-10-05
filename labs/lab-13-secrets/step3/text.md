# Step 3 — Consume as a mounted file

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: sec-file }
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh","-c","ls /etc/db; cat /etc/db/username; echo; sleep 3600"]
    volumeMounts:
    - { name: creds, mountPath: /etc/db, readOnly: true }
  volumes:
  - name: creds
    secret: { secretName: db-creds, defaultMode: 0400 }
EOF
kubectl wait --for=condition=Ready pod/sec-file --timeout=60s
kubectl logs sec-file
```

**Expected result:** the listing shows `password` and `username`, then `admin` — one file
per key, named after the key.

Prove the claim that it is memory-backed:

```bash
kubectl exec sec-file -- df -h /etc/db | tail -1
kubectl exec sec-file -- ls -l /etc/db/
```

**Expected result:** the filesystem is `tmpfs`, and the files are symlinks into `..data/`
(the same atomic-swap trick as ConfigMaps). Files mounted from a Secret live in RAM and are
never written to the node's disk.
