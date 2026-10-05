# Step 2 — Readiness probe

```bash
kubectl run ready-demo --image=nginx \
  --overrides='{"spec":{"containers":[{"name":"ready-demo","image":"nginx","readinessProbe":{"httpGet":{"path":"/","port":80},"initialDelaySeconds":3,"periodSeconds":3}}]}}'
kubectl get pod ready-demo -w
```

**Expected result:** `READY` is `0/1` for the first few seconds, then `1/1` once the HTTP
probe succeeds. Ctrl-C to stop.

Readiness decides **traffic**, not restarts. Prove it with a Service:

```bash
kubectl expose pod ready-demo --port=80 --name=ready-svc
kubectl get endpointslices -l kubernetes.io/service-name=ready-svc \
  -o jsonpath='{.items[0].endpoints[0].conditions.ready}{"\n"}'
```

**Expected result:** `true` — the pod is in the Service's endpoints because it is *ready*.
A failing readiness probe would set this to `false` and remove the pod from load balancing
**without** restarting it. That is the whole difference from liveness.

```bash
kubectl delete svc ready-svc
```
