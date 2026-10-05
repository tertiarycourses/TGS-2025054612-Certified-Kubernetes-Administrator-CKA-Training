# Step 1 — Launch two debug pods

```bash
kubectl run client --image=nicolaka/netshoot --command -- sleep 3600
kubectl run server --image=nginx
kubectl wait --for=condition=Ready pod/client pod/server --timeout=60s
kubectl get pods -o wide
```

**Expected result:** both pods `Running`, each with an IP from the cluster's **pod CIDR**
(`192.168.x.x` if you followed Lab 2, `10.244.x.x` with Flannel) — not from the node's
subnet. Note each pod's IP and node.

> On this playground the control plane is tainted, so both pods usually land on `node01`.
> Step 6 is more interesting when they are split across nodes.
