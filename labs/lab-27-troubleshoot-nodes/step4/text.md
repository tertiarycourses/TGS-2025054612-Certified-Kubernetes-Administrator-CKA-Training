# Step 4 — Cordon and drain

Sometimes you need to take a node out of service safely.

```bash
kubectl cordon node01
kubectl get nodes
kubectl drain node01 --ignore-daemonsets --delete-emptydir-data
```

**Expected result:** after `cordon`, `node01` shows `Ready,SchedulingDisabled` — it keeps
running what it has but accepts nothing new. `drain` then evicts the rest and prints
`node/node01 drained`.

```bash
kubectl get pods -A -o wide | grep node01
```

**Expected result:** only DaemonSet pods (CNI, kube-proxy) remain — `--ignore-daemonsets`
leaves them because they are recreated on the node immediately. `uncordon` returns the node
to `Ready`.

> `drain` is `cordon` **plus** eviction, and it respects PodDisruptionBudgets — which is why
> it can hang on a real cluster.

Bring it back:

```bash
kubectl uncordon node01
```
