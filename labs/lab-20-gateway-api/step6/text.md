# Step 6 — Test

The Service to curl is the one NGF provisioned for your Gateway, in the Gateway's
namespace. Find it by its owner rather than guessing a name:

```bash
for s in $(kubectl -n default get svc -o jsonpath='{.items[*].metadata.name}'); do
  owner=$(kubectl -n default get svc "$s" -o jsonpath='{.metadata.ownerReferences[0].kind}' 2>/dev/null)
  [ "$owner" = "Gateway" ] && GW_SVC=$s
done
echo "data-plane service: $GW_SVC"
kubectl -n default get svc "$GW_SVC"

NODEPORT=$(kubectl -n default get svc "$GW_SVC" -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
echo "nodePort: $NODEPORT"
```

Make sure the backend has a ready endpoint first — the data plane can only forward to one:

```bash
until kubectl get endpointslices -l kubernetes.io/service-name=echo \
  -o jsonpath='{.items[*].endpoints[*].conditions.ready}' | grep -q true; do
  echo "waiting for an echo endpoint..."; sleep 5
done
curl -s -H "Host: echo.local" http://localhost:$NODEPORT
curl -s -o /dev/null -w "wrong host: %{http_code}\n" -H "Host: nope.local" http://localhost:$NODEPORT
```

**Expected result:**

```text
gateway works
wrong host: 404
```

**Read the two status codes — they localise any failure precisely:**

| Response | Meaning |
|---|---|
| `gateway works` | host matched, route resolved, backend healthy |
| `404` | **no route matched** — the `Host` header is not in the HTTPRoute's `hostnames` |
| `503 Service Temporarily Unavailable` | route matched, but **no ready endpoint** behind the backend Service |

So a `503` for `echo.local` is not a routing problem: the Gateway and HTTPRoute are working,
and the `echo` pod is not ready (still pulling, crash-looping) or the Service's
`targetPort` is wrong. Diagnose in that order:

```bash
kubectl get pods -l app=echo -o wide
kubectl get endpointslices -l kubernetes.io/service-name=echo \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]} ready={.conditions.ready}{"\n"}{end}'
kubectl get httproute echo-route -o jsonpath='{.status.parents[0].conditions[*].type}={.status.parents[0].conditions[*].status}{"\n"}'
kubectl describe pod -l app=echo | tail -15
```

**Expected result:** a `Running` pod, one `ready=true` endpoint, and
`Accepted=True ResolvedRefs=True` on the route. Whichever of those is wrong is your
answer.
