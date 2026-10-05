# Step 5 — Create an HTTPRoute

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: echo-route }
spec:
  parentRefs:
  - name: web
  hostnames: ["echo.local"]
  rules:
  - matches:
    - path: { type: PathPrefix, value: / }
    backendRefs:
    - { name: echo, port: 80 }
EOF
kubectl get httproute echo-route -o yaml | grep -A12 "^status:"
```

**Expected result:** the status lists `parents` with
`conditions: Accepted=True` and `ResolvedRefs=True`.

Those two conditions answer different questions: **Accepted** means the Gateway adopted the
route (the `parentRefs` matched and the listener allows it), while **ResolvedRefs** means
every `backendRefs` Service was found. A typo in the backend name leaves Accepted `True`
and ResolvedRefs `False` — read both before debugging anything else.
