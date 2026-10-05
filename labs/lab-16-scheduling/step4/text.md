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
kubectl rollout status deploy/spread --timeout=30s || true
kubectl get pods -l app=spread -o wide
```

**Expected result:** a Deployment does not create pods synchronously — it creates a
ReplicaSet, which then creates the pods — so an immediate `kubectl get pods` returns
`No resources found`. That is why `rollout status` comes first: it **times out** here,
correctly, reporting `1 out of 2 new replicas have been updated`, and the listing then
shows one pod `Running` and one `Pending`.

That split **is** the lesson, not a failure. Read why from the pending pod:

```bash
PENDING=$(kubectl get pods -l app=spread --field-selector status.phase=Pending \
  -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $PENDING | grep -A4 Events
```

**Expected result:** an event naming both obstacles, for example
`1 node(s) didn't match pod anti-affinity rules, 1 node(s) had untolerated taint(s)`.

`requiredDuringScheduling` anti-affinity with `topologyKey: kubernetes.io/hostname` permits
at most **one** `app=spread` pod per node. Only the worker is schedulable (the control
plane is tainted), so the second replica has nowhere left to go.

> If `No resources found` persists for more than a few seconds, the Deployment itself was
> rejected — check `kubectl describe deploy spread` and `kubectl get rs -l app=spread`.

In a real multi-node cluster the two would land on different nodes — which is exactly how
you spread replicas across failure domains. Swap `required` for
`preferredDuringSchedulingIgnoredDuringExecution` and the second pod schedules anyway,
sharing the node.
