# Step 3 — Default-deny ingress

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny, namespace: netpol }
spec:
  podSelector: {}
  policyTypes: [Ingress]
EOF
```

Re-test:

```bash
kubectl -n netpol exec client-ok  -- curl -s --max-time 3 http://server || echo BLOCKED
kubectl -n netpol exec client-bad -- curl -s --max-time 3 http://server || echo BLOCKED
```

**Expected result:** `BLOCKED` twice, after a ~3 second timeout each.

Note *how* it fails: the request **times out** rather than being refused. A dropped packet
looks like a hang, which is why "my app is slow" is so often a NetworkPolicy problem.

`podSelector: {}` selects **every** pod in the namespace, and naming `Ingress` in
`policyTypes` with no `ingress:` rules means "allow nothing in". Egress is untouched —
these pods can still make outbound calls.
