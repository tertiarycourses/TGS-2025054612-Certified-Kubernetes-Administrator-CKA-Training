# Step 2 — Fault 1: selector mismatch

```bash
kubectl patch svc web --type=merge -p '{"spec":{"selector":{"app":"wrong"}}}'
kubectl exec probe -- curl -s --max-time 3 http://web || echo TIMEOUT
kubectl get endpointslices -l kubernetes.io/service-name=web
```

**Expected result:** `TIMEOUT`, and the EndpointSlice has **no addresses** (or none ready).
The Service still exists and DNS still resolves — it simply points at nothing, so the
connection hangs until the timeout.

```bash
kubectl get svc web -o jsonpath='{.spec.selector}{"\n"}'
kubectl get pods -l app=web --show-labels
```

**Expected result:** the selector says `{"app":"wrong"}` while the pods are labelled
`app=web`. **An empty endpoint list always means selector-versus-label**, and it is the
single most common Service bug.

Fix:

```bash
kubectl patch svc web --type=merge -p '{"spec":{"selector":{"app":"web"}}}'
kubectl get endpointslices -l kubernetes.io/service-name=web \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{"\n"}{end}'
```

**Expected result:** two pod IPs listed again.

> `kubectl get endpoints` still works but the Endpoints API is **deprecated since v1.33** —
> read EndpointSlices on a modern cluster.
