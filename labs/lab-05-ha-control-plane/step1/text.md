# Step 1 — The topology, and what you actually have

```
                      clients: kubectl, kubelets
                                  │
                        VIP / load balancer :6443
                                  │
            ┌─────────────────────┼─────────────────────┐
            ▼                     ▼                     ▼
          cp-1                  cp-2                  cp-3     ← apiserver + etcd member
            │                     │                     │
            └─────────────────────┼─────────────────────┘
                                  ▼
                               workers
```

Measure your own cluster:

```bash
kubectl get nodes -l node-role.kubernetes.io/control-plane
kubectl -n kube-system get cm kubeadm-config -o yaml | grep -i controlPlaneEndpoint || \
  echo "no controlPlaneEndpoint: this cluster is NOT HA-ready"
```

One control plane, and no `controlPlaneEndpoint` — so the node's own IP is baked into every
certificate and kubeconfig. That is why a load balancer cannot simply be added later.

```bash
NODE=$(hostname)
kubectl -n kube-system get pods -l component=etcd -o wide
kubectl -n kube-system exec etcd-$NODE -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list -w table
```

Exactly one member, named after your node (the pod is `etcd-<nodename>`).

| etcd members | Quorum needed | Failures tolerated |
|---|---|---|
| 1 | 1 | 0 |
| 2 | 2 | 0 |
| 3 | 2 | 1 |
| 5 | 3 | 2 |

Two members tolerate **no** failures, which is why HA control planes come in odd
numbers. Quorum is `(n/2)+1` rounded down plus one — lose quorum and etcd goes
read-only, so the cluster keeps serving existing pods but accepts no changes.
