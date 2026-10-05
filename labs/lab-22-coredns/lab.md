# Lab 22 — CoreDNS

CoreDNS is the default in-cluster DNS server. Every pod gets `/etc/resolv.conf` pointing to its ClusterIP. In this lab you inspect CoreDNS, query different record types, and customize the Corefile.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Find the CoreDNS Service

```bash
kubectl -n kube-system get svc kube-dns
kubectl -n kube-system get pods -l k8s-app=kube-dns
kubectl -n kube-system get configmap coredns -o yaml
```

**Expected result:** a Service named `kube-dns` with ClusterIP `10.96.0.10`, two CoreDNS
pods `Running`, and a Corefile containing the `kubernetes cluster.local` plugin.

`kube-dns` is the Service name for backward compatibility even though the pods run
CoreDNS — every pod's `/etc/resolv.conf` points at that ClusterIP.

---

## Step 2 — Run a query pod

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

The `nameserver` is the kube-dns ClusterIP, and the `search` list is why short names work
inside the cluster.

---

## Step 3 — Query Service records

```bash
kubectl create deployment web --image=nginx
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
  - name: http          # the port MUST be named for the SRV record in Step 5
    port: 80
    targetPort: 80
EOF
kubectl exec dnsdebug -- dig +short web.default.svc.cluster.local
kubectl exec dnsdebug -- dig +short web   # short name via search list
```

**Expected result:** both lookups return the Service's ClusterIP (a `10.96.x.x` address),
not a pod IP. A ClusterIP Service gets one A record pointing at the virtual IP.

> The Service is written out instead of using `kubectl expose` for one reason: `expose`
> creates an **unnamed** port, and SRV records are published as
> `_<port-name>._<protocol>.<service>…`. With no name there is no `_http._tcp` record, and
> Step 5 would return nothing at all.

---

## Step 4 — Pod records (headless services)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata: { name: web-h }
spec:
  clusterIP: None
  selector: { app: web }
  ports: [{ port: 80 }]
EOF
kubectl exec dnsdebug -- dig +short web-h.default.svc.cluster.local
kubectl get pods -l app=web -o jsonpath='{.items[*].status.podIP}{"\n"}'
```

**Expected result:** the two outputs match — the headless lookup returns the **pod IPs**
directly, because `clusterIP: None` means there is no virtual IP to hand out. Clients then
load-balance themselves, which is what StatefulSet peers rely on.

---

## Step 5 — SRV records

```bash
kubectl exec dnsdebug -- dig SRV _http._tcp.web.default.svc.cluster.local +short
```

**Expected result:** something like
`0 100 80 web.default.svc.cluster.local.` — priority, weight, **port 80**, and the target
host.

An SRV record carries the port as well as the host, so a client can discover *where* and
*on which port* to connect. The `_http` label comes from the port's `name:` in Step 3 —
with an unnamed port this query returns nothing.

---

## Step 6 — Customize the Corefile

Add a stub zone that forwards `example.com` to a public resolver. Back the Corefile up
first, and do it without an interactive editor:

```bash
kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' > /tmp/Corefile.bak
cp /tmp/Corefile.bak /tmp/Corefile.new
cat >> /tmp/Corefile.new <<'EOF'
example.com:53 {
    errors
    forward . 8.8.8.8
}
EOF
kubectl -n kube-system create configmap coredns \
  --from-file=Corefile=/tmp/Corefile.new \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n kube-system rollout restart deploy coredns
kubectl -n kube-system rollout status deploy coredns --timeout=120s
```

**Expected result:** the rollout completes and the new zone is in place:

```bash
kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' | tail -5
kubectl exec dnsdebug -- dig +short www.example.com
```

**Expected result:** the Corefile ends with your `example.com:53` block, and the query
returns public IP addresses — resolved through the stub zone rather than the cluster zone.

> **A broken Corefile breaks all cluster DNS.** CoreDNS will `CrashLoopBackOff` and every
> pod loses name resolution. That is why you saved a backup: restore with
>
> ```bash
> kubectl -n kube-system create configmap coredns --from-file=Corefile=/tmp/Corefile.bak \
>   --dry-run=client -o yaml | kubectl apply -f -
> kubectl -n kube-system rollout restart deploy coredns
> ```

---

## Step 7 — Cleanup

```bash
kubectl -n kube-system create configmap coredns --from-file=Corefile=/tmp/Corefile.bak \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n kube-system rollout restart deploy coredns
kubectl -n kube-system rollout status deploy coredns --timeout=120s
kubectl delete pod dnsdebug
kubectl delete svc web web-h
kubectl delete deploy web
```

**Expected result:** the Corefile is back to the backup and CoreDNS is `Running`. **Revert
the Corefile before other labs** — a stub zone left behind causes confusing DNS results
later.

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — CoreDNS | `kube-dns` Service on `10.96.0.10`, two pods Running |
| Step 2 — resolv.conf | `nameserver 10.96.0.10`, search list, `ndots:5` |
| Step 3 — A record | both lookups return the ClusterIP |
| Step 4 — headless | the lookup returns the pod IPs, matching `get pods` |
| Step 5 — SRV | `0 100 80 web.default.svc.cluster.local.` |
| Step 6 — stub zone | `dig www.example.com` returns public addresses |
| Step 7 — reverted | Corefile restored, CoreDNS Running |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| SRV query returns nothing | The Service port is unnamed. Create it with `name: http` as in Step 3. |
| CoreDNS `CrashLoopBackOff` after Step 6 | The Corefile is invalid: `kubectl -n kube-system logs -l k8s-app=kube-dns`, then restore the backup. |
| All DNS fails cluster-wide | Same cause. Restore `/tmp/Corefile.bak` and restart the Deployment. |
| `dig: command not found` | Run it from the `dnsdebug` (netshoot) pod, not the node. |
| Short name resolves but the FQDN does not | Check the `search` list and that you used `.svc.cluster.local`. |
| `nslookup` works but `dig` is empty | `dig +short` prints nothing on NXDOMAIN — drop `+short` to see the status. |

---

## What you learned
- `<svc>.<ns>.svc.<cluster-domain>` is the canonical Service FQDN.
- Headless Services return pod IPs; SRV records expose ports.
- The Corefile in `kube-system/coredns` ConfigMap controls all DNS behaviour.
