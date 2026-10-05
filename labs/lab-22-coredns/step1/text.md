# Step 1 — Find the CoreDNS Service

```bash
kubectl -n kube-system get svc kube-dns
kubectl -n kube-system get pods -l k8s-app=kube-dns
kubectl -n kube-system get configmap coredns -o yaml
```

**Expected result:** a Service named `kube-dns` with ClusterIP `10.96.0.10`, two CoreDNS
pods `Running`, and a Corefile containing the `kubernetes cluster.local` plugin.

`kube-dns` is the Service name for backward compatibility even though the pods run
CoreDNS — every pod's `/etc/resolv.conf` points at that ClusterIP.
