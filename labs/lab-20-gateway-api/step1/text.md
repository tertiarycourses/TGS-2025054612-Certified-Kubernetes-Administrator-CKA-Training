# Step 1 — Install the Gateway API CRDs

The Gateway API is **not** built into Kubernetes — it ships as CRDs. Install the version
your controller supports, not simply the newest:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
kubectl get crds | grep gateway.networking.k8s.io
```

**Expected result:** `gatewayclasses`, `gateways`, `grpcroutes` and `httproutes` in group
`gateway.networking.k8s.io`.

> **Why v1.6.1?** NGINX Gateway Fabric v2.7.2 (Step 2) is built against Gateway API v1.6.1
> and also supports v1.5.1. Mismatched versions are the usual cause of a Gateway that never
> gets an address. The `standard` channel carries GA resources; `experimental` adds TCPRoute
> and TLSRoute.
