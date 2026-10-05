# Step 2 — Install a Gateway controller (NGINX Gateway Fabric)

NGINX Gateway Fabric moved from the `nginxinc` org to `nginx`, and restructured its
manifests — the old `deploy/manifests/nginx-gateway.yaml` path now returns **404**. Use the
current release, and the **nodeport** variant so there is a port you can curl on a
playground:

```bash
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.7.2/deploy/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.7.2/deploy/nodeport/deploy.yaml
kubectl -n nginx-gateway wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=nginx-gateway --timeout=300s
kubectl -n nginx-gateway get pods
kubectl get gatewayclass
```

**Expected result:** the `nginx-gateway` pod is `Running` (a short-lived
`nginx-gateway-cert-generator` Job shows `Completed`), and a GatewayClass named **nginx**
is `ACCEPTED True` with controller `gateway.nginx.org/nginx-gateway-controller`.

> Two label traps in one step: the pod label is `app.kubernetes.io/name=nginx-gateway`,
> **not** `nginx-gateway-fabric` as in v1 — a wait on the old label just times out. And
> `deploy/crds.yaml` installs NGF's *own* CRDs (`NginxProxy`, `NginxGateway`), which are
> separate from the Gateway API CRDs in Step 1.
