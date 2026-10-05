# Step 4 — Test with Host header

```bash
NODEPORT=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
echo "http nodePort: $NODEPORT"
curl -s -H "Host: app1.local" http://localhost:$NODEPORT
curl -s -H "Host: app2.local" http://localhost:$NODEPORT
curl -s -o /dev/null -w "no Host header: %{http_code}\n" http://localhost:$NODEPORT
```

**Expected result:**

```text
hello from app1
hello from app2
no Host header: 404
```

One controller, one port, two hostnames — that is **host-based routing**. The third request
returns `404` because no rule matches an empty host: the Ingress routes on the `Host`
header, not on the IP or port. These hostnames are not in DNS, which is why `-H "Host: …"`
stands in for it.
