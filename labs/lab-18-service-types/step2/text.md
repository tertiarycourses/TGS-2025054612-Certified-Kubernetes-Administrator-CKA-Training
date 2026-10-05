# Step 2 — ClusterIP (default)

```bash
kubectl expose deploy web --port=80 --name=web-clusterip
kubectl get svc web-clusterip
kubectl get endpoints web-clusterip
CIP=$(kubectl get svc web-clusterip -o jsonpath='{.spec.clusterIP}')
kubectl run probe --image=busybox --rm -it --restart=Never -- wget -qO- $CIP | head -5
```

**Expected result:** the Service has a `10.96.x.x` ClusterIP, its endpoints list **three**
pod IPs on port 80, and the probe prints nginx's welcome HTML.

```bash
curl -s --max-time 5 http://$CIP || echo "not reachable from the node - correct"
```

**Expected result:** the curl **fails**. A ClusterIP is a virtual address programmed into
each node's iptables/IPVS rules for *pods*; it is not routable from the host network. That
is why Step 3 exists.
