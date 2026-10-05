# Step 6 — Pending due to taint

Pick the **worker**: the control plane is already `NoSchedule`-tainted, so tainting it
would prove nothing — the pod would simply schedule on the worker.

```bash
NODE=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  -o jsonpath='{.items[0].metadata.name}')
echo "tainting: $NODE"
kubectl taint node $NODE dedicated=critical:NoSchedule
kubectl -n app run untol --image=nginx
sleep 5
kubectl -n app get pod untol
kubectl -n app describe pod untol | grep -A4 Events
```

**Expected result:** `Pending`, with both nodes rejecting it —
`1 node(s) had untolerated taint {dedicated: critical}` for the worker and
`{node-role.kubernetes.io/control-plane: }` for the control plane. With every node repelling
the pod, there is nowhere left to put it.

Fix:

```bash
kubectl taint node $NODE dedicated-
```
