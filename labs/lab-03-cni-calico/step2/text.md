# Step 2 — Watch pods come up

```bash
kubectl get pods -n kube-system -w
```

Rather than watching, wait for it:

```bash
kubectl -n kube-system rollout status ds/calico-node --timeout=300s
kubectl -n kube-system get pods -l k8s-app=calico-node -o wide
kubectl get nodes
```

**Expected result:** `calico-node` shows `2 of 2 updated and available`, one pod per node
with `1/1` ready, and **both nodes `Ready`**.

On a 1-CPU node this takes a few minutes: each `calico-node` pod runs init containers that
install the CNI plugin before the main container starts. CoreDNS, stuck `Pending` since
Lab 2, now gets an IP and starts:

```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns
```

**Expected result:** both CoreDNS pods `Running` — the clearest signal that the pod network
is live.
