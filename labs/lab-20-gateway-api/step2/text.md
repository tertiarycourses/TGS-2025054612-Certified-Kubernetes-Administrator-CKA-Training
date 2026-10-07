# Step 2 — Install a Gateway controller (NGINX Gateway Fabric)

NGINX Gateway Fabric moved from the `nginxinc` org to `nginx`, and restructured its
manifests — the old `deploy/manifests/nginx-gateway.yaml` path now returns **404**. Use the
current release, and the **nodeport** variant so there is a port you can curl on a
playground:

```bash
kubectl apply --server-side -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.7.2/deploy/crds.yaml
kubectl get crds | grep gateway.nginx.org | head
```

**Expected result:** twelve or so `gateway.nginx.org` CRDs, including
**`nginxproxies.gateway.nginx.org`** — the big one, and the reason `--server-side` is not
optional here.

Only once those exist can the controller be installed, because its manifest contains an
`NginxProxy` resource:

```bash
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.7.2/deploy/nodeport/deploy.yaml
kubectl -n nginx-gateway wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=nginx-gateway --timeout=300s
kubectl -n nginx-gateway get pods
kubectl get gatewayclass
```

> **Order matters, and the error says so.** If the CRD apply is skipped or fails, this step
> stops with
> `no matches for kind "NginxProxy" in version "gateway.nginx.org/v1alpha2"` and
> `ensure CRDs are installed first`. Install the CRDs, then re-run this.


**Expected result:** the `nginx-gateway` pod is `Running` (a short-lived
`nginx-gateway-cert-generator` Job shows `Completed`), and a GatewayClass named **nginx**
is `ACCEPTED True` with controller `gateway.nginx.org/nginx-gateway-controller`.

> Two label traps in one step: the pod label is `app.kubernetes.io/name=nginx-gateway`,
> **not** `nginx-gateway-fabric` as in v1 — a wait on the old label just times out. And
> `deploy/crds.yaml` installs NGF's *own* CRDs (`NginxProxy`, `NginxGateway`), which are
> separate from the Gateway API CRDs in Step 1.
