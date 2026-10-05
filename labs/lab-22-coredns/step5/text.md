# Step 5 — SRV records

```bash
kubectl exec dnsdebug -- dig SRV _http._tcp.web.default.svc.cluster.local +short
```

**Expected result:** something like
`0 100 80 web.default.svc.cluster.local.` — priority, weight, **port 80**, and the target
host.

An SRV record carries the port as well as the host, so a client can discover *where* and
*on which port* to connect. The `_http` label comes from the port's `name:` in Step 3 —
with an unnamed port this query returns nothing.
