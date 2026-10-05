# Step 4 — Pod anti-affinity (spread)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata: { name: spread }
spec:
  replicas: 2
  selector: { matchLabels: { app: spread } }
  template:
    metadata: { labels: { app: spread } }
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels: { app: spread }
            topologyKey: kubernetes.io/hostname
      containers:
      - { name: app, image: nginx }
EOF
kubectl get pods -l app=spread -o wide
kubectl describe pod -l app=spread | grep -A3 Events | tail -5
```

**Expected result on this playground: one pod `Running`, one pod `Pending`** — and that is
the lesson, not a failure. `requiredDuringScheduling` anti-affinity with
`topologyKey: kubernetes.io/hostname` permits at most one `app=spread` pod per node. Only
the worker is schedulable (the control plane is tainted), so the second replica has nowhere
to go and reports
`didn't match pod anti-affinity rules`.

In a real multi-node cluster the two would land on different nodes — which is exactly how
you spread replicas across failure domains. Swap `required` for
`preferredDuringSchedulingIgnoredDuringExecution` and the second pod schedules anyway,
sharing the node.
