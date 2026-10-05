# Lab 17 — Pod-to-Pod Connectivity

Every pod gets a routable IP and can reach every other pod without NAT. In this lab you prove the model end-to-end with `netshoot`, a tools-rich debug image.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Launch two debug pods

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

---

## Step 2 — Ping by pod IP

```bash
SERVER_IP=$(kubectl get pod server -o jsonpath='{.status.podIP}')
kubectl exec client -- ping -c 3 $SERVER_IP
```

**Expected result:** `3 packets transmitted, 3 received, 0% packet loss`.

Now prove there is no NAT — ask the server what address the request came from:

```bash
kubectl exec client -- curl -s $SERVER_IP > /dev/null
kubectl logs server | tail -2
kubectl get pod client -o jsonpath='{.status.podIP}{"\n"}'
```

**Expected result:** the nginx access log shows **the client pod's own IP**, identical to
the second command's output. No SNAT, no port mapping: that flat, NAT-free pod network is
the Kubernetes network model.

---

## Step 3 — Curl the nginx pod directly

```bash
kubectl exec client -- curl -s -o /dev/null -w "%{http_code}\n" http://$SERVER_IP
```

**Expected result:** `200` — straight to the pod IP, with no Service in the path.

---

## Step 4 — DNS-based discovery

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

---

## Step 5 — Inspect routing inside the pod

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

---

## Step 6 — Traceroute across nodes (if multi-node)

```bash
kubectl exec client -- traceroute -n $SERVER_IP
kubectl get pods -o wide | awk '{print $1, $6, $7}'
```

**Expected result:** if both pods share a node, **one hop** — the traffic never leaves it.
Across nodes you see two or three hops via the node's CNI overlay.

Either outcome is correct; compare it with the `NODE` column. Pods on one node talk over a
virtual bridge inside that node, which is why same-node traffic is measurably faster.

---

## Step 7 — Cleanup

```bash
kubectl delete pod client server
kubectl delete svc server
```

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — pods up | both `Running` with pod-CIDR IPs (not node IPs) |
| Step 2 — ping and no NAT | `0% packet loss`; nginx logs the client pod's own IP |
| Step 3 — direct HTTP | `200` straight to the pod IP |
| Step 4 — DNS | `server` resolves to a ClusterIP from the service range (`10.96.0.0/12`, e.g. `10.103.244.102`); curl returns `200` |
| Step 5 — pod networking | `nameserver 10.96.0.10`, `ndots:5`, CNI default route |
| Step 6 — traceroute | one hop on the same node, two or three across nodes |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `kubectl exec` fails with `unable to upgrade connection` | The pod is not Running yet: `kubectl get pod client`. |
| `ping: permission denied` | Some CNIs block ICMP. Use the curl check in Step 3 instead — it proves reachability too. |
| `nslookup server` returns NXDOMAIN | The Service does not exist yet (Step 4's `expose`), or CoreDNS is down: `kubectl -n kube-system get pods -l k8s-app=kube-dns`. |
| `;; Got recursion not available from 10.96.0.10` | Cosmetic. CoreDNS does not advertise recursion to pods; the `Name:`/`Address:` lines are the answer. |
| ClusterIP is not `10.96.0.x` | Normal — the range is `10.96.0.0/12`, so up to `10.111.255.255`. |
| nginx logs show a node IP, not the pod IP | Traffic was SNATed — you curled a NodePort or an external address, not the pod IP. |
| Both pods always on one node | The control plane is tainted, so only the worker is schedulable. Expected here. |
| `traceroute: command not found` | Run it from the `client` (netshoot) pod, not from `server` (nginx). |

---

## What you learned
- Flat pod network with no NAT between pods.
- Pod IPs are ephemeral — use Service DNS for stability.
- How to use `netshoot` to debug from inside the cluster.
