# Step 5 — Inspect Endpoints & EndpointSlices

```bash
kubectl get endpointslices -l kubernetes.io/service-name=web-clusterip
kubectl get endpointslices -l kubernetes.io/service-name=web-clusterip \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]} ready={.conditions.ready}{"\n"}{end}'
kubectl get endpoints web-clusterip
```

**Expected result:** one EndpointSlice holding three addresses, each `ready=true`, and the
legacy `Endpoints` object showing the same three IPs.

> **EndpointSlices are the current API.** The `Endpoints` object is deprecated as of
> Kubernetes v1.33 — it is still written for compatibility, and `kubectl get endpoints` may
> warn. One Endpoints object listed every address, which did not scale; EndpointSlices cap
> at 100 endpoints each and shard beyond that. Read slices, not endpoints, on a modern
> cluster.

Scale the Deployment and watch the slice follow:

```bash
kubectl scale deploy/web --replicas=1
sleep 5
kubectl get endpointslices -l kubernetes.io/service-name=web-clusterip \
  -o jsonpath='{.items[0].endpoints[*].addresses[0]}{"\n"}'
kubectl scale deploy/web --replicas=3
```

**Expected result:** one address after scaling down. The endpoint list is derived from
**ready** pods — which is the mechanism behind readiness probes gating traffic (Lab 15).
