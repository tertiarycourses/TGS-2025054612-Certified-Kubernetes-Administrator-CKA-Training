# Step 4 — DNS-based discovery

Expose `server` as a Service:

```bash
kubectl expose pod server --port=80
kubectl exec client -- nslookup server
kubectl exec client -- curl -s -o /dev/null -w "%{http_code}\n" http://server
kubectl get svc server
```

**Expected result:** `nslookup` resolves `server.default.svc.cluster.local` to the
Service's **ClusterIP** — an address from the service range, **not** the pod IP — and the
curl returns `200`:

```text
Server:         10.96.0.10
Address:        10.96.0.10#53

Name:   server.default.svc.cluster.local
Address: 10.103.244.102
```

> **Why not `10.96.0.x`?** kubeadm's default service range is `10.96.0.0/12` — everything from `10.96.0.0` to `10.111.255.255` — and ClusterIPs are allocated across it, so yours may well read `10.103.244.102`. Only `kube-dns` is predictable: it always takes the tenth address, `10.96.0.10`. Confirm the range your cluster uses with
> `kubectl -n kube-system get pod -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep service-cluster-ip-range`.

> **`;; Got recursion not available from 10.96.0.10` is not an error.** CoreDNS answers for cluster names but does not advertise *recursion* to pods, so BIND's `nslookup` prints that line before and after a perfectly good answer. If the `Name:` and `Address:` lines are there, DNS worked. `dig` shows the same thing as a missing `ra` flag in its header.


That is the difference worth remembering: the pod IP changes whenever the pod is replaced;
the Service name and ClusterIP do not. Lab 18 covers Service types.
