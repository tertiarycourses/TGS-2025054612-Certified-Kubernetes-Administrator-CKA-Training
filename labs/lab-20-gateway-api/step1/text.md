# Step 1 — Install the Gateway API CRDs

The Gateway API is **not** built into Kubernetes — it ships as CRDs. Install the version
your controller supports, not simply the newest:

```bash
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
kubectl get crds | grep gateway.networking.k8s.io
```

**Expected result:** each CRD reported as `serverside-applied`, and the list shows
`gatewayclasses`, `gateways`, `grpcroutes` and `httproutes` in group
`gateway.networking.k8s.io`.

> **Why `--server-side`?** Plain `kubectl apply` saves a copy of everything it sends in the `kubectl.kubernetes.io/last-applied-configuration` **annotation**, and annotations may not exceed **262144 bytes**. These CRDs are far bigger — Gateway API's `httproutes` is about 429 KB and NGF's `nginxproxies` about 700 KB — so a client-side apply fails with:
>
> ```text
> The CustomResourceDefinition "..." is invalid: metadata.annotations: Too long: may not be more than 262144 bytes
> ```
>
> Server-side apply has the API server track field ownership instead of writing that annotation, so size stops mattering. If you already tried a client-side apply, add `--force-conflicts` to take ownership of the fields it left behind.


> **Why v1.6.1?** NGINX Gateway Fabric v2.7.2 (Step 2) is built against Gateway API v1.6.1
> and also supports v1.5.1. Mismatched versions are the usual cause of a Gateway that never
> gets an address. The `standard` channel carries GA resources; `experimental` adds TCPRoute
> and TLSRoute.
