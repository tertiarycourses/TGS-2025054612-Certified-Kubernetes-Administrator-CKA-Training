# Step 1 — Install ingress-nginx

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
