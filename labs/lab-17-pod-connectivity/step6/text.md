# Step 6 — Traceroute across nodes (if multi-node)

```bash
kubectl exec client -- traceroute -n $SERVER_IP
kubectl get pods -o wide | awk '{print $1, $6, $7}'
```

**Expected result:** if both pods share a node, **one hop** — the traffic never leaves it.
Across nodes you see two or three hops via the node's CNI overlay.

Either outcome is correct; compare it with the `NODE` column. Pods on one node talk over a
virtual bridge inside that node, which is why same-node traffic is measurably faster.
