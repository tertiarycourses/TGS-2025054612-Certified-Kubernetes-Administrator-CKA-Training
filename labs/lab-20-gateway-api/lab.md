# Lab 20 — Gateway API

The Gateway API is Kubernetes' next-generation ingress: role-oriented (GatewayClass / Gateway / HTTPRoute) and CRD-driven. In this lab you install the API plus a controller (nginx-gateway-fabric) and route HTTP traffic with an HTTPRoute.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Install the Gateway API CRDs

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

---

## Step 2 — Install a Gateway controller (NGINX Gateway Fabric)

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

---

## Step 3 — Deploy a backend

```bash
kubectl create deployment echo --image=hashicorp/http-echo --port=5678 -- -text="gateway works"
kubectl expose deploy echo --port=80 --target-port=5678
```

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
curl -s -H "Host: echo.local" http://localhost:$NODEPORT
curl -s -o /dev/null -w "wrong host: %{http_code}\n" -H "Host: nope.local" http://localhost:$NODEPORT
```

**Expected result:**

```text
gateway works
wrong host: 404
```

The matching host is routed by the HTTPRoute; anything else gets `404` — the same
host-based routing as Ingress, but expressed in a separate, dev-owned object.

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
| Step 1 — Gateway API CRDs | `gatewayclasses`, `gateways`, `httproutes` in `gateway.networking.k8s.io` |
| Step 2 — controller | `nginx-gateway` pod Running; GatewayClass `nginx` `ACCEPTED True` |
| Step 3 — backend | `echo` Deployment and Service created |
| Step 4 — Gateway | `PROGRAMMED True`, and a provisioned `web-nginx` Deployment/Service appears |
| Step 5 — HTTPRoute | `Accepted=True` and `ResolvedRefs=True` |
| Step 6 — traffic | `gateway works` for `echo.local`, `404` for any other host |
| Step 8 — cleanup | deleting the Gateway removes its provisioned Deployment and Service |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `404 page not found` fetching the controller manifest | The old `nginxinc` path is gone. Use the `nginx/nginx-gateway-fabric` v2 URLs in Step 2. |
| `wait` times out with no matching pods | The v2 label is `app.kubernetes.io/name=nginx-gateway`, not `nginx-gateway-fabric`. |
| GatewayClass is not `ACCEPTED` | Gateway API CRD version mismatch — NGF v2.7.2 wants v1.6.1 (or v1.5.1). |
| Gateway stays `PROGRAMMED False` | `kubectl -n nginx-gateway logs deploy/nginx-gateway` — usually a missing NginxProxy CRD from `deploy/crds.yaml`. |
| No Service to curl in `nginx-gateway` | Correct for v2: the data plane is provisioned per Gateway in the Gateway's namespace. Use the discovery loop in Step 6. |
| HTTPRoute `ResolvedRefs=False` | The `backendRefs` Service name or port is wrong, or it is in another namespace without a ReferenceGrant. |
| `curl` returns 404 for the right host | `hostnames:` must match the `Host` header exactly — `echo.local` here. |

---

## What you learned
- The three Gateway API objects: GatewayClass, Gateway, HTTPRoute.
- Role separation: infra installs Gateway, dev creates HTTPRoute.
- How Gateway API generalizes beyond HTTP.
