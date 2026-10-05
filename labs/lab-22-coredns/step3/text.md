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

**Expected result:** both lookups return the Service's ClusterIP (a `10.96.x.x` address),
not a pod IP. A ClusterIP Service gets one A record pointing at the virtual IP.

> The Service is written out instead of using `kubectl expose` for one reason: `expose`
> creates an **unnamed** port, and SRV records are published as
> `_<port-name>._<protocol>.<service>…`. With no name there is no `_http._tcp` record, and
> Step 5 would return nothing at all.
