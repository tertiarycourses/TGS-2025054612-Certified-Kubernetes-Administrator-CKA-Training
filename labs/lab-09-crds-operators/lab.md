# Lab 9 — CRDs and Operators

A CustomResourceDefinition (CRD) extends the Kubernetes API with new object kinds. An Operator is a controller that watches a CRD and reconciles real-world state. In this lab you define a tiny CRD by hand, then install **cert-manager** as a real-world operator to see the pattern in production.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Define a CRD

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: widgets.training.example.com
spec:
  group: training.example.com
  scope: Namespaced
  names:
    plural: widgets
    singular: widget
    kind: Widget
    shortNames: [wg]
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              color:   { type: string }
              size:    { type: integer, minimum: 1, maximum: 100 }
EOF
```

---

## Step 2 — Use the new resource

```bash
kubectl api-resources | grep widgets
cat <<'EOF' | kubectl apply -f -
apiVersion: training.example.com/v1
kind: Widget
metadata:
  name: blue-widget
spec:
  color: blue
  size: 7
EOF
kubectl get widgets
kubectl describe widget blue-widget
```

**Expected result:** `api-resources` lists `widgets` with short name `wg`, and
`kubectl get widgets` shows `blue-widget`. Prove the schema is enforced — this must be
**rejected**:

```bash
kubectl apply -f - <<'EOF'
apiVersion: training.example.com/v1
kind: Widget
metadata:
  name: too-big
spec:
  color: red
  size: 500
EOF
```

**Expected result:** `spec.size: Invalid value: 500: spec.size in body should be less than
or equal to 100` — the API server validated your custom object against the CRD's schema.

The CRD gives you storage and validation, but **no controller is reconciling it** — `kubectl get widgets` reads from etcd, nothing else happens. That's the missing operator piece.

---

## Step 3 — Install a real operator (cert-manager)

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.21.2 \
  --set crds.enabled=true \
  --wait --timeout 5m
kubectl -n cert-manager get pods
```

**Expected result:** three Deployments ready — `cert-manager`, `cert-manager-webhook` and
`cert-manager-cainjector`. On a 1-CPU node this takes a few minutes, which is why `--wait`
is there.

> **Pin the version** (`--version v1.21.2`): operators ship CRDs, and an unpinned install
> can bring a schema your manifests do not match. Note also `--set crds.enabled=true` —
> charts before v1.15 spelled this `installCRDs=true`.

Before creating any cert-manager object, make sure its **admission webhook** is actually
serving. This is the single most common cert-manager failure:

```bash
kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=180s
kubectl get validatingwebhookconfigurations cert-manager-webhook \
  -o jsonpath='{.webhooks[0].clientConfig.service.name}{"\n"}'
```

**Expected result:** the rollout is complete and the webhook points at
`cert-manager-webhook`. Applying a `Certificate` too early fails with
`Internal error occurred: failed calling webhook "webhook.cert-manager.io"`.

This installs the cert-manager Deployments **and** several CRDs:

```bash
kubectl get crds | grep cert-manager
```

You should see `certificates`, `issuers`, `clusterissuers`, `certificaterequests`, `orders`, `challenges`.

---

## Step 4 — Create a self-signed Issuer + Certificate

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Issuer
metadata: { name: selfsigned, namespace: default }
spec: { selfSigned: {} }
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: { name: test-cert, namespace: default }
spec:
  secretName: test-cert-tls
  duration: 24h
  commonName: example.local
  issuerRef:
    name: selfsigned
    kind: Issuer
EOF
```

```bash
kubectl get certificate
kubectl get secret test-cert-tls
kubectl describe certificate test-cert | tail -5
```

**Expected result:** `test-cert` reports `READY True`, and Secret `test-cert-tls` exists of
type `kubernetes.io/tls` with `tls.crt` and `tls.key`. The events end with
`Certificate issued successfully`. If `READY` stays `False`, read
`kubectl describe certificate test-cert` — the reason is always in its events.

Cert-manager's controller saw the `Certificate` object, ran the issuance flow, and created the `test-cert-tls` Secret containing `tls.crt` + `tls.key`. **That** is the operator pattern.

---

## Step 5 — Clean up

```bash
kubectl delete certificate test-cert
kubectl delete issuer selfsigned
kubectl delete widget blue-widget
kubectl delete crd widgets.training.example.com
helm -n cert-manager uninstall cert-manager
kubectl delete ns cert-manager
kubectl get crds | grep cert-manager.io || echo "cert-manager CRDs removed"
```

**Expected result:** the Widget CRD and its instance are gone, and the cert-manager CRDs
are removed too (the chart installed them because of `crds.enabled=true`, so `helm
uninstall` takes them away). **Deleting a CRD deletes every object of that kind** — there is
no undo, which is why operators ship them separately from the workload.

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — CRD applied | `customresourcedefinition.apiextensions.k8s.io/widgets.training.example.com created` |
| Step 2 — new kind usable | `kubectl get widgets` lists `blue-widget`; `size: 500` is rejected by the schema |
| Step 3 — operator installed | three cert-manager Deployments ready; webhook rollout complete |
| Step 4 — reconciliation | `test-cert` is `READY True` and Secret `test-cert-tls` exists |
| Step 5 — cleanup | no `cert-manager.io` CRDs remain |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `failed calling webhook "webhook.cert-manager.io"` | The webhook is not serving yet. `kubectl -n cert-manager rollout status deploy/cert-manager-webhook`, then re-apply. |
| Certificate stays `READY False` | `kubectl describe certificate test-cert` — the cause is in the events (usually a missing or mistyped `issuerRef`). |
| cert-manager pods `Pending` for minutes | 1 CPU is tight. Wait, or check `kubectl -n cert-manager describe pod` for `Insufficient cpu`. |
| `no matches for kind "Widget"` | The CRD is not established yet: `kubectl get crd widgets.training.example.com -o jsonpath='{.status.conditions[?(@.type=="Established")].status}'`. |
| `error validating data: unknown field` | Your object has a field the CRD's schema does not define. Only `color` and `size` exist here. |
| CRDs survive `helm uninstall` | Older charts used `installCRDs`; delete leftovers with `kubectl delete crd -l app.kubernetes.io/instance=cert-manager`. |

---

## What you learned
- A CRD adds a typed, validated object kind to the API.
- Without a controller, a CRD is just storage.
- An operator = CRD(s) + controller loop, demonstrated by cert-manager.
