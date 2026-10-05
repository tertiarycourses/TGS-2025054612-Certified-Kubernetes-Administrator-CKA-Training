# Step 6 — Taints and tolerations

```bash
kubectl taint node $NODE workload=batch:NoSchedule
kubectl run notol --image=nginx
sleep 5
kubectl get pod notol -o wide
kubectl describe pod notol | grep -A3 Events
```

**Expected result:** `notol` is **`Pending`**. Both nodes now repel it — the control plane
with its own `NoSchedule` taint, and `$NODE` with the `workload=batch` taint you just
added. The event reads
`0/2 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 1 node(s) had untolerated taint {workload: batch}`.

A taint repels pods; a toleration is a pod saying "that one does not apply to me".

Add a toleration:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: tolerant }
spec:
  tolerations:
  - { key: workload, operator: Equal, value: batch, effect: NoSchedule }
  containers:
  - { name: app, image: nginx }
EOF
kubectl get pod tolerant -o wide
```

**Expected result:** `tolerant` is `Running` on `$NODE` — same cluster, same taint, but this
pod tolerates it.

> A toleration **permits**, it does not **attract**. `tolerant` could still have landed
> anywhere that accepted it; use `nodeSelector` or affinity when you need to *target* a
> node.

Remove the taint:

```bash
kubectl taint node $NODE workload-
```
