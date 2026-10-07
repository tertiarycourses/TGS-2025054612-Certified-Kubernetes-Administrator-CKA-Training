# Lab 19 — Ingress Controller and Resources

An Ingress controller is a reverse proxy (typically nginx, Traefik, or Envoy) running inside the cluster that routes external HTTP/HTTPS based on `Ingress` objects. In this lab you install ingress-nginx and route two hostnames to two Services.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Install ingress-nginx

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/baremetal/deploy.yaml
kubectl -n ingress-nginx wait --for=condition=Ready pod \
  -l app.kubernetes.io/component=controller --timeout=300s
kubectl -n ingress-nginx get pods
kubectl -n ingress-nginx get svc
kubectl get ingressclass
```

**Expected result:** the controller pod is `Running`, two admission `Job` pods show
`Completed`, the `ingress-nginx-controller` Service is of type `NodePort`, and an
IngressClass named `nginx` exists.

On a 1-CPU node this can take two or three minutes — hence the 300s timeout.

> **Pin the version.** The lab previously fetched this manifest from the `main` branch,
> which changes without warning and has broken classes mid-course. `controller-v1.15.1` is
> a release tag: reproducible today and next term. The `baremetal` variant is the right one
> here because it creates a **NodePort** Service — the `cloud` variant would sit at
> `<pending>` forever.

---

## Step 2 — Deploy two backends

```bash
kubectl create deployment app1 --image=hashicorp/http-echo:1.0 --port=5678 -- \
  -text="hello from app1"
kubectl create deployment app2 --image=hashicorp/http-echo:1.0 --port=5678 -- \
  -text="hello from app2"
kubectl rollout status deploy/app1 --timeout=180s
kubectl rollout status deploy/app2 --timeout=180s
kubectl expose deploy app1 --port=80 --target-port=5678
kubectl expose deploy app2 --port=80 --target-port=5678
kubectl get pods -l 'app in (app1,app2)'
kubectl run probe --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- http://app1
```

**Expected result:** both pods Running, and the probe prints `hello from app1` — the
backends work *before* any Ingress exists, so a later failure is the Ingress, not the app.

> `--target-port=5678` matters: `http-echo` listens on 5678 while the Service publishes 80.
> A mismatch here is the most common "502 from the Ingress" cause. The image is pinned to
> `:1.0` rather than `latest` so the lab behaves the same every time.

If the rollout times out with `0 of 1 updated replicas are available` and the endpoint shows `ready=false`, the container never started. Read the events — they name the cause:

```bash
kubectl get pods -l app=app1 -o wide
kubectl describe pod -l app=app1 | sed -n '/Events/,$p'
kubectl logs -l app=app1 --tail=20
```

| Status | Cause |
|---|---|
| `ErrImagePull` / `ImagePullBackOff` with `toomanyrequests` | Docker Hub is rate-limiting the playground's shared IP. Wait and retry, or use the fallback below. |
| `ImagePullBackOff` with `no such host` | The node has no registry access. |
| `CrashLoopBackOff` | The container started and exited — `kubectl logs` shows why. |
| `ContainerCreating` for minutes | The pull is simply slow on a 1-CPU node; wait. |

**Fallback that needs no new pull.** `nginx` is already on both nodes from earlier labs, so it always works — the routing lesson is identical, you just get nginx's welcome page instead of the echo text:

```bash
kubectl delete deploy app1
kubectl create deployment app1 --image=nginx --port=80
kubectl expose deploy app1 --port=80 --target-port=80 --name=app1
kubectl rollout status deploy/app1 --timeout=180s
```

Delete the old Service first if its `targetPort` no longer matches: `kubectl delete svc app1`.

> With nginx as the backend, expect its welcome page instead of `hello from app1` — the
> host-based routing in Step 4 is unchanged, which is the point of the step.

---

## Step 3 — Create the Ingress

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

---

## Step 4 — Test with Host header

```bash
NODEPORT=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
echo "http nodePort: $NODEPORT"
curl -s -H "Host: app1.local" http://localhost:$NODEPORT
curl -s -H "Host: app2.local" http://localhost:$NODEPORT
curl -s -o /dev/null -w "no Host header: %{http_code}\n" http://localhost:$NODEPORT
```

**Expected result:**

```text
hello from app1
hello from app2
no Host header: 404
```

One controller, one port, two hostnames — that is **host-based routing**. The third request
returns `404` because no rule matches an empty host: the Ingress routes on the `Host`
header, not on the IP or port. These hostnames are not in DNS, which is why `-H "Host: …"`
stands in for it.

---

## Step 5 — Add TLS

```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
  -keyout tls.key -out tls.crt -subj "/CN=app1.local"
kubectl create secret tls app1-tls --cert=tls.crt --key=tls.key

kubectl patch ingress demo --type=merge \
  -p '{"spec":{"tls":[{"hosts":["app1.local"],"secretName":"app1-tls"}]}}'

HTTPS=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
curl -sk -H "Host: app1.local" https://localhost:$HTTPS
curl -sv -k -H "Host: app1.local" https://localhost:$HTTPS 2>&1 | grep -E "subject:|issuer:"
```

**Expected result:** `hello from app1` over HTTPS, and the certificate's subject is
`CN=app1.local` — your Secret, served by the controller. `-k` is required because the
certificate is self-signed.

> **Use JSON for `--type=merge`.** A YAML patch string works only sometimes; JSON always
> does, and it is what the API expects. The controller watches the Secret, so TLS starts
> working within a second or two of the patch — no restart.

---

## Step 6 — Path-based routing (reference)

```yaml
rules:
- http:
    paths:
    - { path: /a, pathType: Prefix, backend: { service: { name: app1, port: { number: 80 } } } }
    - { path: /b, pathType: Prefix, backend: { service: { name: app2, port: { number: 80 } } } }
```

---

## Step 7 — Cleanup

```bash
kubectl delete ingress demo
kubectl delete secret app1-tls
kubectl delete svc app1 app2
kubectl delete deploy app1 app2
rm tls.key tls.crt
```

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — controller | controller pod Running, admission Jobs `Completed`, NodePort Service, IngressClass `nginx` |
| Step 2 — backends | both pods Running; the probe prints `hello from app1` |
| Step 3 — Ingress | both host rules listed; `ADDRESS` populated |
| Step 4 — host routing | `hello from app1`, `hello from app2`, and `404` with no Host header |
| Step 5 — TLS | `hello from app1` over HTTPS with subject `CN=app1.local` |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Controller pod `Pending` for minutes | 1 CPU is tight. Wait, or `kubectl -n ingress-nginx describe pod` for `Insufficient cpu`. |
| `ADDRESS` on the Ingress stays empty | No controller claimed it: check `ingressClassName: nginx` against `kubectl get ingressclass`. |
| `502 Bad Gateway` | The Service's `--target-port` does not match the container port (5678 for http-echo). |
| `404` for every request | A missing or misspelled `Host` header, or a host that is not in the rules. |
| `admission webhook "validate.nginx.ingress.kubernetes.io" denied` | The admission Job has not finished. Wait for `Completed`, then re-apply. |
| TLS still serves the default certificate | The Secret name or namespace is wrong — it must be in the Ingress's namespace and of type `kubernetes.io/tls`. |

---

## What you learned
- Controller (the proxy pod) vs Ingress resource (the routing rule).
- Host-based and path-based routing.
- TLS termination via a `tls` Secret.
