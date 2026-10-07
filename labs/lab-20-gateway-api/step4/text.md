# Step 4 — Create a Gateway

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: web, namespace: default }
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces: { from: All }
EOF
kubectl get gateway
until [ "$(kubectl get gateway web \
  -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}')" = "True" ]; do
  echo "waiting for the Gateway to be programmed..."; sleep 5
done
kubectl get gateway web -o jsonpath='{.status.conditions[*].type}={.status.conditions[*].status}{"\n"}'
```

**Expected result:** eventually `Accepted Programmed=True True`.

Read immediately after `apply`, the Gateway shows `PROGRAMMED Unknown` and
`Programmed=Unknown` — NGF has accepted it but has not finished provisioning the data
plane yet, which is why this waits rather than reading the condition once.

**This is where NGF v2 differs sharply from v1 and from Ingress:** creating the Gateway
makes NGF **provision a data plane for it** — an nginx Deployment and Service in the
*Gateway's own namespace*, owned by the Gateway:

```bash
kubectl -n default get deploy,svc
```

**Expected result:** a new Deployment and Service (named after the Gateway, typically
`web-nginx`) that you did not create. Delete the Gateway and they go with it. In v1 a
single shared data plane lived in `nginx-gateway`, which is why the old Step 6 looked for
the Service there.
