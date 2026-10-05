# Step 3 — Query Service records

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

**Expected result:** both lookups return the Service's ClusterIP — an address from the
service range, not a pod IP. A ClusterIP Service gets one A record pointing at the virtual
IP.

> **Why not `10.96.0.x`?** kubeadm's default service range is `10.96.0.0/12` — everything from `10.96.0.0` to `10.111.255.255` — and ClusterIPs are allocated across it, so yours may well read `10.103.244.102`. Only `kube-dns` is predictable: it always takes the tenth address, `10.96.0.10`. Confirm the range your cluster uses with
> `kubectl -n kube-system get pod -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep service-cluster-ip-range`.


> The Service is written out instead of using `kubectl expose` for one reason: `expose`
> creates an **unnamed** port, and SRV records are published as
> `_<port-name>._<protocol>.<service>…`. With no name there is no `_http._tcp` record, and
> Step 5 would return nothing at all.
