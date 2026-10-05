# Step 4 — DNS-based discovery

Expose `server` as a Service:

```bash
kubectl expose pod server --port=80
kubectl exec client -- nslookup server
kubectl exec client -- curl -s -o /dev/null -w "%{http_code}\n" http://server
kubectl get svc server
```

**Expected result:** `nslookup` resolves `server.default.svc.cluster.local` to the
Service's **ClusterIP** (a `10.96.x.x` address — not the pod IP), and the curl returns
`200`.

That is the difference worth remembering: the pod IP changes whenever the pod is replaced;
the Service name and ClusterIP do not. Lab 18 covers Service types.
