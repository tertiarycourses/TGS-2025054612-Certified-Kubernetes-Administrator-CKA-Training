# Step 1 — Liveness probe

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: live-demo }
spec:
  containers:
  - name: app
    image: busybox
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm /tmp/healthy; sleep 600
    livenessProbe:
      exec: { command: ["cat","/tmp/healthy"] }
      initialDelaySeconds: 5
      periodSeconds: 5
EOF
kubectl get pod live-demo -w
```

**Expected result:** the pod is `Running` for about 35 seconds, then `RESTARTS` increments
to `1`, and keeps climbing roughly every 35-40 seconds. Press Ctrl-C to stop watching.

The container deleted its own health file, so `cat /tmp/healthy` started failing. Read the
kubelet's own words:

```bash
kubectl describe pod live-demo | grep -A5 Events
```

**Expected result:** `Liveness probe failed: cat: can't open '/tmp/healthy'` followed by
`Container app failed liveness probe, will be restarted`.

> **Liveness restarts the container, it does not reschedule the pod.** The pod keeps its
> name, IP and node — only the container inside is recreated, which is why `RESTARTS` is a
> per-container counter.
