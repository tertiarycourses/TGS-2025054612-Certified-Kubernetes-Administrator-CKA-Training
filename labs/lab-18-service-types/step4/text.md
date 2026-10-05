# Step 4 — LoadBalancer

```bash
kubectl expose deploy web --port=80 --type=LoadBalancer --name=web-lb
kubectl get svc web-lb
```

**Expected result:** `EXTERNAL-IP` is `<pending>`, and it stays that way. Nothing is
broken: `type=LoadBalancer` asks the *cloud provider* for an address, and bare metal has
none. The Service still works as a NodePort in the meantime:

```bash
kubectl get svc web-lb
```

**MetalLB** fills that gap on bare metal. Install it pinned, then give it addresses from
**your own node's subnet** — a pool from a different network can never be reached:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml
kubectl -n metallb-system rollout status deploy/controller --timeout=180s
kubectl -n metallb-system rollout status ds/speaker --timeout=180s
```

Derive the pool from the node's own address instead of copying a range from a tutorial:

```bash
NODE_IP=$(kubectl get node -o jsonpath='{.items[0].status.addresses[0].address}')
SUBNET=$(echo $NODE_IP | cut -d. -f1-3)
echo "node $NODE_IP -> pool ${SUBNET}.240-${SUBNET}.250"

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata: { name: pool, namespace: metallb-system }
spec: { addresses: ["${SUBNET}.240-${SUBNET}.250"] }
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata: { name: l2, namespace: metallb-system }
EOF

kubectl get svc web-lb
LB_IP=$(kubectl get svc web-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -s -o /dev/null -w "%{http_code}\n" http://$LB_IP
```

**Expected result:** `EXTERNAL-IP` becomes an address from that range (for example
`172.30.1.240`) within a few seconds, and the curl returns `200`.

> **Why the range matters.** MetalLB in L2 mode answers ARP for these addresses on the
> node's own link, so they must be free addresses **in the node's subnet**. The
> `172.18.255.x` pool you will see in most tutorials is `kind`'s docker network — it
> cannot work here. If `EXTERNAL-IP` stays `<pending>`, read
> `kubectl -n metallb-system logs deploy/controller`.
