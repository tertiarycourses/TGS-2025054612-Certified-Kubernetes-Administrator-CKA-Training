# Step 3 — configMap and secret as files

Done in Lab 12 and Lab 13 — re-check:

```bash
kubectl create configmap demo-cfg --from-literal=greeting=hi
kubectl create secret generic demo-sec --from-literal=token=s3cret

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: mount-demo }
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh","-c","cat /cfg/greeting /sec/token; sleep 3600"]
    volumeMounts:
    - { name: cfg, mountPath: /cfg }
    - { name: sec, mountPath: /sec }
  volumes:
  - { name: cfg, configMap: { name: demo-cfg } }
  - { name: sec, secret:    { secretName: demo-sec } }
EOF
kubectl wait --for=condition=Ready pod/mount-demo --timeout=60s
kubectl logs mount-demo
kubectl exec mount-demo -- df -h /cfg /sec | tail -2
```

**Expected result:** `hi` then `s3cret`, and both mounts report **`tmpfs`** — ConfigMap and
Secret volumes are memory-backed, so their contents are never written to the node's disk.
