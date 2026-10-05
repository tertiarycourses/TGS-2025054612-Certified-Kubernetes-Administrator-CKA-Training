# Step 4 — DaemonSet (one pod per node)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata: { name: log-agent, namespace: kube-system }
spec:
  selector: { matchLabels: { app: log-agent } }
  template:
    metadata: { labels: { app: log-agent } }
    spec:
      tolerations:
      - operator: Exists
      containers:
      - name: agent
        image: busybox
        command: ["sh","-c","while true; do echo log; sleep 60; done"]
EOF
kubectl -n kube-system get ds log-agent
kubectl -n kube-system get pods -l app=log-agent -o wide
```

**Expected result:** `DESIRED 2  CURRENT 2  READY 2` on a two-node cluster, and the pods sit
on **different** nodes — one per node, including the control plane thanks to
`tolerations: [{operator: Exists}]`, which tolerates every taint.

```bash
kubectl -n kube-system get pods -l app=log-agent \
  -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}'
```

**Expected result:** both node names, each once. A DaemonSet has no `replicas` field —
its count *is* the number of matching nodes, so adding a node adds a pod automatically.
