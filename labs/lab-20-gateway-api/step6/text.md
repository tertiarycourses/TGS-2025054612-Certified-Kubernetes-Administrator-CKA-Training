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
curl -s -H "Host: echo.local" http://localhost:$NODEPORT
curl -s -o /dev/null -w "wrong host: %{http_code}\n" -H "Host: nope.local" http://localhost:$NODEPORT
```

**Expected result:**

```text
gateway works
wrong host: 404
```

The matching host is routed by the HTTPRoute; anything else gets `404` — the same
host-based routing as Ingress, but expressed in a separate, dev-owned object.
