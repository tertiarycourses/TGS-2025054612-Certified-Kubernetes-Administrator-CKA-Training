# Step 4 — Allow only the trusted client

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-trusted, namespace: netpol }
spec:
  podSelector: { matchLabels: { app: server } }
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector: { matchLabels: { role: allowed } }
    ports:
    - { protocol: TCP, port: 80 }
EOF
```

```bash
kubectl -n netpol exec client-ok  -- curl -s -o /dev/null -w "%{http_code}\n" http://server   # 200
kubectl -n netpol exec client-bad -- curl -s --max-time 3 http://server || echo BLOCKED
```

**Expected result:** `200` from `client-ok` and `BLOCKED` from `client-bad`.

Policies are **additive and never deny**: `default-deny` still exists, and this second
policy only adds an allowance. There is no ordering or priority in NetworkPolicy — the
union of all matching policies is what is permitted.
