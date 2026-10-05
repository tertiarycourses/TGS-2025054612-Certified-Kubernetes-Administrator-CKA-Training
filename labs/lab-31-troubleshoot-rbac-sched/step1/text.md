# Step 1 — Create a broken setup

```bash
kubectl create ns app
kubectl -n app create sa worker
kubectl -n app run worker-pod \
  --image=curlimages/curl:8.11.1 \
  --overrides='{"spec":{"serviceAccountName":"worker"}}' \
  --command -- sleep 3600
kubectl -n app wait --for=condition=Ready pod/worker-pod --timeout=120s
kubectl -n app get pod worker-pod -o jsonpath='{.spec.serviceAccountName}{"\n"}'
```

**Expected result:** `worker`. If it says `default`, the override did not apply and every
result below will be wrong — delete the pod and re-run.

Now ask the API server, as the ServiceAccount, using the token mounted in the pod:

```bash
kubectl -n app exec worker-pod -- sh -c '
SA=/var/run/secrets/kubernetes.io/serviceaccount
curl -s -o /dev/null -w "list pods -> %{http_code}\n" --cacert $SA/ca.crt \
  -H "Authorization: Bearer $(cat $SA/token)" \
  https://kubernetes.default.svc/api/v1/namespaces/app/pods'
```

**Expected result:** `list pods -> 403` — authenticated, but not authorised. A brand-new
ServiceAccount can do nothing.

> **Two traps avoided here.** `kubectl run` has **no** `--serviceaccount` flag — it must be
> set through `--overrides`. And the old `bitnami/kubectl` image comes from Bitnami's
> retired catalog: pinning a version now fails outright
> (`bitnami/kubectl:1.33.1` → 404). Calling the API with `curl` and the pod's own token
> needs no kubectl in the image, and shows RBAC as a plain HTTP status.
