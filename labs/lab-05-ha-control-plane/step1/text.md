# Step 1 — Topology, quorum, and what makes a cluster HA-ready

The standard layout is **stacked etcd**: every control-plane node runs an apiserver *and*
an etcd member, behind one load-balanced address.

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

| Piece | Why | Command |
|---|---|---|
| A shared endpoint | baked into certificates and kubeconfigs, so clients and new control planes use the LB, not one node's IP | `kubeadm init --control-plane-endpoint "k8s-vip:6443"` |
| Uploaded certificates | lets control plane #2 and #3 join without copying PKI by hand | `--upload-certs`, then `kubeadm join … --control-plane --certificate-key <key>` |
| A TCP load balancer | passes 6443 through to each apiserver; HAProxy + keepalived for the floating IP | `frontend … bind *:6443`, `mode tcp` |

Check where your own cluster stands:

```bash
kubectl get nodes -l node-role.kubernetes.io/control-plane
kubectl -n kube-system get cm kubeadm-config -o yaml | grep -i controlPlaneEndpoint || \
  echo "no controlPlaneEndpoint: this cluster cannot gain more control planes without reissuing certs"
```

**Expected result:** one control-plane node. Whether `controlPlaneEndpoint` appears depends
on how you bootstrapped: `kubeadm init` without `--control-plane-endpoint` bakes in the
node's own IP, and adding a load balancer later means reissuing certificates. That is the
single most important HA decision, and it is made in the first command you run.

> **Why we stop here:** a second control plane needs its own VM with 2 CPUs. Adding one on
> this playground fails on resources, not on your understanding. The rest of the lab spends
> its time on something you *can* complete end to end — and that the exam weights heavily.
