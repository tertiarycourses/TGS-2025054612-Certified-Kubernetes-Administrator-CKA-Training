# Step 3 — Grant minimal access

```bash
kubectl -n app create role pod-reader --verb=get,list,watch --resource=pods
kubectl -n app create rolebinding worker-reader --role=pod-reader --serviceaccount=app:worker
kubectl -n app auth can-i list pods --as=system:serviceaccount:app:worker
kubectl -n app exec worker-pod -- sh -c '
SA=/var/run/secrets/kubernetes.io/serviceaccount
curl -s -o /dev/null -w "list pods -> %{http_code}\n" --cacert $SA/ca.crt \
  -H "Authorization: Bearer $(cat $SA/token)" \
  https://kubernetes.default.svc/api/v1/namespaces/app/pods'
```

**Expected result:** `yes`, and `list pods -> 200`. No restart was needed — RBAC is
evaluated per request, so the binding takes effect immediately.
