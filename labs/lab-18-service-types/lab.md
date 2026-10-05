# Lab 18 — Service Types: ClusterIP, NodePort, LoadBalancer

In this lab you expose the same Deployment with each of the three primary Service types and inspect the resulting Endpoints.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Deploy a workload

```bash
kubectl create deployment web --image=nginx --replicas=3
kubectl rollout status deploy/web
kubectl get pods -l app=web -o wide
```

---

## Step 2 — ClusterIP (default)

```bash
kubectl expose deploy web --port=80 --name=web-clusterip
kubectl get svc web-clusterip
kubectl get endpoints web-clusterip
CIP=$(kubectl get svc web-clusterip -o jsonpath='{.spec.clusterIP}')
kubectl run probe --image=busybox --rm -it --restart=Never -- wget -qO- $CIP | head -5
```

**Expected result:** the Service has a ClusterIP from the service range (kubeadm's default
is `10.96.0.0/12`, so anything up to `10.111.255.255` — `10.103.244.102` is as valid as
`10.96.1.5`), its endpoints list **three** pod IPs on port 80, and the probe prints nginx's
welcome HTML.

```bash
curl -s --max-time 5 http://$CIP || echo "not reachable from the node - correct"
```

**Expected result:** the curl **fails**. A ClusterIP is a virtual address programmed into
each node's iptables/IPVS rules for *pods*; it is not routable from the host network. That
is why Step 3 exists.

---

## Step 3 — NodePort

```bash
kubectl expose deploy web --port=80 --type=NodePort --name=web-nodeport
kubectl get svc web-nodeport
PORT=$(kubectl get svc web-nodeport -o jsonpath='{.spec.ports[0].nodePort}')
echo "nodePort: $PORT"
curl -s http://localhost:$PORT | head -5
```

**Expected result:** a port in the **30000-32767** range, and nginx's HTML. The same port
answers on *every* node, including ones running none of the pods — kube-proxy forwards from
whichever node you hit:

```bash
NODE_IP=$(kubectl get node -o jsonpath='{.items[1].status.addresses[0].address}')
curl -s -o /dev/null -w "from %s: %%{http_code}\n" http://$NODE_IP:$PORT
```

**Expected result:** `200` from the other node too. A NodePort is a superset of ClusterIP —
it keeps the ClusterIP and adds the host port.

---

## Step 4 — LoadBalancer

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

---

## Step 5 — Inspect Endpoints & EndpointSlices

```bash
kubectl get endpointslices -l kubernetes.io/service-name=web-clusterip
kubectl get endpointslices -l kubernetes.io/service-name=web-clusterip \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]} ready={.conditions.ready}{"\n"}{end}'
kubectl get endpoints web-clusterip
```

**Expected result:** one EndpointSlice holding three addresses, each `ready=true`, and the
legacy `Endpoints` object showing the same three IPs.

> **EndpointSlices are the current API.** The `Endpoints` object is deprecated as of
> Kubernetes v1.33 — it is still written for compatibility, and `kubectl get endpoints` may
> warn. One Endpoints object listed every address, which did not scale; EndpointSlices cap
> at 100 endpoints each and shard beyond that. Read slices, not endpoints, on a modern
> cluster.

Scale the Deployment and watch the slice follow:

```bash
kubectl scale deploy/web --replicas=1
sleep 5
kubectl get endpointslices -l kubernetes.io/service-name=web-clusterip \
  -o jsonpath='{.items[0].endpoints[*].addresses[0]}{"\n"}'
kubectl scale deploy/web --replicas=3
```

**Expected result:** one address after scaling down. The endpoint list is derived from
**ready** pods — which is the mechanism behind readiness probes gating traffic (Lab 15).

---

## Step 6 — Cleanup

```bash
kubectl delete svc web-clusterip web-nodeport web-lb
kubectl delete deploy web
# MetalLB claims node addresses, so remove it before other networking labs:
kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml --ignore-not-found
```

**Expected result:** all three Services and the Deployment are gone, and the
`metallb-system` namespace is removed.

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — workload | three `web` pods Running |
| Step 2 — ClusterIP | three endpoints; reachable from a pod, **not** from the node |
| Step 3 — NodePort | a port in 30000-32767 answering `200` on every node |
| Step 4 — LoadBalancer | `<pending>` without MetalLB; a node-subnet IP with it, curl `200` |
| Step 5 — EndpointSlices | three `ready=true` addresses; one after scaling to a single replica |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `curl $CIP` fails from the node | Correct — a ClusterIP is only routable from pods. Use NodePort or `kubectl run` a probe pod. |
| `EXTERNAL-IP` stays `<pending>` | No load-balancer provider. Install MetalLB, and check `kubectl -n metallb-system logs deploy/controller`. |
| MetalLB assigns an unreachable IP | The pool is not in the node's subnet. Derive it from `NODE_IP` as Step 4 does. |
| `speaker` pods `CrashLoopBackOff` | MetalLB's speaker needs host networking and privileged ports; on a locked-down playground stick to NodePort. |
| `kubectl get endpoints` warns about deprecation | Expected on v1.33+. Use `kubectl get endpointslices` instead. |
| NodePort unreachable from the other node | A firewall or the CNI is blocking it; test from the node that hosts a pod first. |

---

## What you learned
- ClusterIP (in-cluster), NodePort (cluster-wide host port), LoadBalancer (cloud LB or MetalLB).
- The Endpoints / EndpointSlice link between Service and Pods.
- Why bare-metal needs MetalLB to use `type=LoadBalancer`.
