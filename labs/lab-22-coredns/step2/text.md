# Step 2 — Run a query pod

```bash
kubectl run dnsdebug --image=nicolaka/netshoot --command -- sleep 3600
kubectl wait --for=condition=Ready pod/dnsdebug --timeout=60s
kubectl exec dnsdebug -- cat /etc/resolv.conf
```

**Expected result:**

```text
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

The `nameserver` is the kube-dns ClusterIP — always the tenth address of the service
range — and the `search` list is why short names work inside the cluster.

> **`;; Got recursion not available from 10.96.0.10` is not an error.** CoreDNS answers for cluster names but does not advertise *recursion* to pods, so BIND's `nslookup` prints that line before and after a perfectly good answer. If the `Name:` and `Address:` lines are there, DNS worked. `dig` shows the same thing as a missing `ra` flag in its header.
