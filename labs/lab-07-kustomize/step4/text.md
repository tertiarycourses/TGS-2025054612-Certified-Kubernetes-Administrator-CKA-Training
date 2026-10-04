# Step 4 — Render and apply

`kubectl kustomize` renders; `kubectl apply -k` renders **and** applies. The namespaces an
overlay names must already exist:

```bash
kubectl create ns web-dev
kubectl create ns web-prod
kubectl apply -k kustom/overlays/dev
kubectl apply -k kustom/overlays/prod
```

Now compare the two environments built from one base:

```bash
for ns in web-dev web-prod; do
  echo "== $ns"
  kubectl -n $ns get deploy web \
    -o jsonpath='{.spec.replicas} replicas, image {.spec.template.spec.containers[0].image}{"\n"}'
done
```

**Expected result:**

```text
== web-dev
1 replicas, image nginx:1.25
== web-prod
4 replicas, image nginx:1.27
```

On a 1-CPU node the four prod pods may take a minute; `kubectl -n web-prod get pods -w`
shows progress. The label from the base is on both:

```bash
kubectl -n web-prod get deploy web --show-labels
```

**Expected result:** labels include `app=web`.
