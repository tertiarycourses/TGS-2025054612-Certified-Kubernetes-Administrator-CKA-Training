# Lab 20 — Gateway API

The Gateway API is Kubernetes' next-generation ingress: role-oriented (GatewayClass / Gateway / HTTPRoute) and CRD-driven. In this lab you install the API plus a controller (nginx-gateway-fabric) and route HTTP traffic with an HTTPRoute.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Install the Gateway API CRDs

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

---

## Step 2 — Install a Gateway controller (NGINX Gateway Fabric)

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

---

## Step 3 — Deploy a backend

```bash
kubectl create deployment echo --image=hashicorp/http-echo --port=5678 -- -text="gateway works"
kubectl expose deploy echo --port=80 --target-port=5678
kubectl rollout status deploy/echo --timeout=180s
kubectl get endpointslices -l kubernetes.io/service-name=echo \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]} ready={.conditions.ready}{"\n"}{end}'
```

**Expected result:** `deployment "echo" successfully rolled out`, and one endpoint address
with `ready=true`.

**Do not skip the wait.** A Gateway can only route to a *ready* endpoint. Curl too early
and you get `503 Service Temporarily Unavailable` from the data plane — the route is fine,
there is simply nothing healthy behind it. Confirm the backend works before involving the
Gateway at all:

```bash
kubectl run probe --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- http://echo
```

**Expected result:** `gateway works` — printed by the backend itself. Now any failure in
Step 6 belongs to the Gateway, not the app.

> `--target-port=5678` matters: `http-echo` listens on 5678 while the Service publishes 80.
> A mismatch here is the other common cause of a 503.

---

## Step 4 — Create a Gateway

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
kubectl get gateway web -o jsonpath='{.status.conditions[*].type}={.status.conditions[*].status}{"\n"}'
```

**Expected result:** `web` reports `PROGRAMMED True` within a few seconds.

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

---

## Step 5 — Create an HTTPRoute

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

---

## Step 6 — Test

The Service to curl is the one NGF provisioned for your Gateway, in the Gateway's
namespace. Find it by its owner rather than guessing a name:

```bash
for s in $(kubectl -n default get svc -o jsonpath='{.items[*].metadata.name}'); do
  owner=$(kubectl -n default get svc "$s" -o jsonpath='{.metadata.ownerReferences[0].kind}' 2>/dev/null)
  [ "$owner" = "Gateway" ] && GW_SVC=$s
done
echo "data-plane service: $GW_SVC"
kubectl -n default get svc "$GW_SVC"

NODEPORT=$(kubectl -n default get svc "$GW_SVC" -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
echo "nodePort: $NODEPORT"
```

Make sure the backend has a ready endpoint first — the data plane can only forward to one:

```bash
until kubectl get endpointslices -l kubernetes.io/service-name=echo \
  -o jsonpath='{.items[*].endpoints[*].conditions.ready}' | grep -q true; do
  echo "waiting for an echo endpoint..."; sleep 5
done
curl -s -H "Host: echo.local" http://localhost:$NODEPORT
curl -s -o /dev/null -w "wrong host: %{http_code}\n" -H "Host: nope.local" http://localhost:$NODEPORT
```

**Expected result:**

```text
gateway works
wrong host: 404
```

**Read the two status codes — they localise any failure precisely:**

| Response | Meaning |
|---|---|
| `gateway works` | host matched, route resolved, backend healthy |
| `404` | **no route matched** — the `Host` header is not in the HTTPRoute's `hostnames` |
| `503 Service Temporarily Unavailable` | route matched, but **no ready endpoint** behind the backend Service |

So a `503` for `echo.local` is not a routing problem: the Gateway and HTTPRoute are working,
and the `echo` pod is not ready (still pulling, crash-looping) or the Service's
`targetPort` is wrong. Diagnose in that order:

```bash
kubectl get pods -l app=echo -o wide
kubectl get endpointslices -l kubernetes.io/service-name=echo \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]} ready={.conditions.ready}{"\n"}{end}'
kubectl get httproute echo-route -o jsonpath='{.status.parents[0].conditions[*].type}={.status.parents[0].conditions[*].status}{"\n"}'
kubectl describe pod -l app=echo | tail -15
```

**Expected result:** a `Running` pod, one `ready=true` endpoint, and
`Accepted=True ResolvedRefs=True` on the route. Whichever of those is wrong is your
answer.

---

## Step 7 — Compare with Ingress

| Concept             | Ingress              | Gateway API             |
|---------------------|----------------------|-------------------------|
| Controller selector | `ingressClassName`   | `GatewayClass`          |
| Cluster object      | `Ingress` (mixed)    | `Gateway` (infra-owned) |
| Route object        | (inside `Ingress`)   | `HTTPRoute` (dev-owned) |
| Protocols           | HTTP/S only          | HTTP, HTTPS, TCP, TLS, gRPC, UDP |
| Cross-namespace     | No                   | Yes (`allowedRoutes`)   |

---

## Step 8 — Cleanup

```bash
kubectl delete httproute echo-route
kubectl delete gateway web
kubectl -n default get deploy,svc
kubectl delete svc echo && kubectl delete deploy echo
```

**Expected result:** deleting the **Gateway** also removes the nginx Deployment and Service
it provisioned — they were owned by it, so garbage collection takes them. Only `echo`
remains until you delete it.

Remove the controller and the CRDs if you are done with Gateway API:

```bash
kubectl delete -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.7.2/deploy/nodeport/deploy.yaml --ignore-not-found
kubectl delete -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.7.2/deploy/crds.yaml --ignore-not-found
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml --ignore-not-found
```

**Expected result:** deleting the Gateway API CRDs removes every Gateway and HTTPRoute in
the cluster — CRD deletion is cluster-wide and irreversible.

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — Gateway API CRDs | each `serverside-applied`; `gatewayclasses`, `gateways`, `httproutes` present in `gateway.networking.k8s.io` |
| Step 2 — controller | `nginxproxies` CRD installed, `nginx-gateway` pod Running, GatewayClass `nginx` `ACCEPTED True` |
| Step 3 — backend | `echo` rolled out, one `ready=true` endpoint, and `wget http://echo` prints `gateway works` |
| Step 4 — Gateway | `PROGRAMMED True`, and a provisioned `web-nginx` Deployment/Service appears |
| Step 5 — HTTPRoute | `Accepted=True` and `ResolvedRefs=True` |
| Step 6 — traffic | `gateway works` for `echo.local`, `404` for any other host (a `503` means the backend is not ready) |
| Step 8 — cleanup | deleting the Gateway removes its provisioned Deployment and Service |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `metadata.annotations: Too long: may not be more than 262144 bytes` | The CRD is bigger than the annotation limit client-side apply uses. Re-run with `kubectl apply --server-side` (add `--force-conflicts` if a client-side apply already touched it). |
| `no matches for kind "NginxProxy" … ensure CRDs are installed first` | The CRD apply did not complete — fix the error above first, then re-apply `deploy/nodeport/deploy.yaml`. |
| `404 page not found` fetching the controller manifest | The old `nginxinc` path is gone. Use the `nginx/nginx-gateway-fabric` v2 URLs in Step 2. |
| `wait` times out with no matching pods | The v2 label is `app.kubernetes.io/name=nginx-gateway`, not `nginx-gateway-fabric`. |
| GatewayClass is not `ACCEPTED` | Gateway API CRD version mismatch — NGF v2.7.2 wants v1.6.1 (or v1.5.1). |
| Gateway stays `PROGRAMMED False` | `kubectl -n nginx-gateway logs deploy/nginx-gateway` — usually a missing NginxProxy CRD from `deploy/crds.yaml`. |
| No Service to curl in `nginx-gateway` | Correct for v2: the data plane is provisioned per Gateway in the Gateway's namespace. Use the discovery loop in Step 6. |
| HTTPRoute `ResolvedRefs=False` | The `backendRefs` Service name or port is wrong, or it is in another namespace without a ReferenceGrant. |
| `curl` returns 404 for the right host | `hostnames:` must match the `Host` header exactly — `echo.local` here. |
| `503 Service Temporarily Unavailable` for the right host | The route matched but no **ready endpoint** exists. Check `kubectl get pods -l app=echo` and the EndpointSlice; also verify the Service's `targetPort` is 5678. Routing is fine — do not touch the Gateway. |

---

## What you learned
- The three Gateway API objects: GatewayClass, Gateway, HTTPRoute.
- Role separation: infra installs Gateway, dev creates HTTPRoute.
- How Gateway API generalizes beyond HTTP.
