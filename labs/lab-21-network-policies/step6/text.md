# Step 6 — Egress policy

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: dns-only, namespace: netpol }
spec:
  podSelector: { matchLabels: { role: denied } }
  policyTypes: [Egress]
  egress:
  - to:
    - namespaceSelector: {}
      podSelector: { matchLabels: { k8s-app: kube-dns } }
    ports:
    - { protocol: UDP, port: 53 }
    - { protocol: TCP, port: 53 }
EOF
kubectl -n netpol exec client-bad -- curl -s --max-time 3 http://1.1.1.1 || echo BLOCKED
kubectl -n netpol exec client-bad -- nslookup kubernetes.default
```

**Expected result:** `BLOCKED` for the outbound HTTP call, but the DNS lookup still
answers with `kubernetes.default.svc.cluster.local` and a `10.96.0.1`-style address.

> **Always allow TCP/53 as well as UDP/53.** Resolvers fall back to TCP for large answers,
> and an egress policy with UDP only produces intermittent, maddening DNS failures. This
> is the single most common self-inflicted egress bug.
>
> Note the `to:` item combines `namespaceSelector: {}` (any namespace) with a
> `podSelector` in the **same** list item — AND, deliberately: only the kube-dns pods, in
> whichever namespace they live.
