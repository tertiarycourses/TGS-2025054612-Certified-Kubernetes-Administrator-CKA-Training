# Step 5 — Inspect routing inside the pod

```bash
kubectl exec client -- ip addr
kubectl exec client -- ip route
kubectl exec client -- cat /etc/resolv.conf
```

**Expected result:** `eth0` holds the pod IP with a `/32` route, the default route points
at a per-node CNI gateway (often `169.254.1.1` with Calico), and `/etc/resolv.conf` reads:

```text
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

`10.96.0.10` is the CoreDNS Service's ClusterIP. The `search` list is why `server` alone
resolved in Step 4, and `ndots:5` is why short names cost extra DNS lookups — a classic
performance question.
