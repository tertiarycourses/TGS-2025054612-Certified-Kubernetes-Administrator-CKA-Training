# Step 1 — HA overview: topology, quorum, and HA-readiness

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

| etcd members | Quorum | Failures tolerated |
|---|---|---|
| 1 | 1 | 0 |
| 2 | 2 | 0 |
| 3 | 2 | 1 |
| 5 | 3 | 2 |

Quorum is `(n/2)+1`. Two members tolerate **nothing** — which is why control planes
come in odd numbers. Lose quorum and etcd goes read-only: running pods keep running,
but no change is accepted.

Three things make a cluster HA-ready, and only the first must be decided at bootstrap:

| Piece | Command |
|---|---|
| A shared endpoint in every cert and kubeconfig | `kubeadm init --control-plane-endpoint "k8s-vip:6443"` |
| Uploaded PKI so other control planes can join | `--upload-certs`, then `kubeadm join … --control-plane --certificate-key <key>` |
| A TCP load balancer in front of the apiservers | HAProxy `mode tcp`, `bind *:6443` |

Check your own cluster:

```bash
kubectl get nodes -l node-role.kubernetes.io/control-plane
kubectl -n kube-system get cm kubeadm-config -o yaml | grep -i controlPlaneEndpoint || \
  echo "no controlPlaneEndpoint: this cluster cannot gain more control planes without reissuing certs"
```

A second control plane needs its own 2-CPU VM, so the rest of this lab moves to etcd backup
and restore — which you can complete end to end here, and which the exam weights heavily.
