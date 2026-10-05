# Step 4 — Inspect the new cluster

Back on **controlplane**:

```bash
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

**Expected result:** two nodes, both `NotReady`, and in `kube-system`:
`kube-apiserver`, `kube-controller-manager`, `kube-scheduler` and `etcd` all `Running`,
`kube-proxy` on both nodes, and **CoreDNS `Pending`**.

CoreDNS is the tell-tale: it needs a pod IP, and no CNI means no pod network, so it cannot
start. Everything else in the control plane runs with `hostNetwork: true` and does not
care. Fix both by installing a CNI in Lab 3.
