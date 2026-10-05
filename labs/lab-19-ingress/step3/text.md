# Step 3 — Create the Ingress

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: app1.local
    http:
      paths:
      - { path: /, pathType: Prefix, backend: { service: { name: app1, port: { number: 80 } } } }
  - host: app2.local
    http:
      paths:
      - { path: /, pathType: Prefix, backend: { service: { name: app2, port: { number: 80 } } } }
EOF
kubectl get ingress
kubectl describe ingress demo | grep -A6 Rules
```

**Expected result:** the Ingress lists both hosts with `app1:80` and `app2:80` backends, and
the `ADDRESS` column fills in with the node IP after a few seconds. An empty `ADDRESS`
means no controller claimed it — check `ingressClassName: nginx` matches the IngressClass
from Step 1.
