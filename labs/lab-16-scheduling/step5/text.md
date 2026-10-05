# Step 5 — Resource requests and limits

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: sized }
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests: { cpu: "100m", memory: "64Mi" }
      limits:   { cpu: "500m", memory: "128Mi" }
EOF
kubectl describe pod sized | grep -A5 -E "Limits|Requests"
kubectl get pod sized -o jsonpath='{.status.qosClass}{"\n"}'
```

**Expected result:** limits `cpu: 500m`, `memory: 128Mi`, requests `cpu: 100m`,
`memory: 64Mi`, and QoS class `Burstable` (requests set, but lower than limits).

The scheduler only considers **requests** when choosing a node; limits are enforced at
runtime by the kernel. See what the node has left:

```bash
kubectl describe node $NODE | grep -A6 "Allocated resources"
```

**Expected result:** a table of requests and limits as percentages of capacity. A pod whose
*request* exceeds what remains stays `Pending` — which is why over-requesting wastes a
cluster.
