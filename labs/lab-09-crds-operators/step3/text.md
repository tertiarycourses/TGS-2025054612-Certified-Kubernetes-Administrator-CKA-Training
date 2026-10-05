# Step 3 — Install a real operator (cert-manager)

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
