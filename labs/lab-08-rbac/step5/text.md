# Step 5 — Test from inside a pod, with the real token

Impersonation proves the rules; the token proves the **enforcement path**. Run a pod *as*
the ServiceAccount. `kubectl run` has no `--serviceaccount` flag, so set it through
`--overrides`:

```bash
kubectl -n rbac-demo run api-test \
  --image=curlimages/curl:8.11.1 \
  --overrides='{"spec":{"serviceAccountName":"viewer"}}' \
  --command -- sleep 3600
kubectl -n rbac-demo wait --for=condition=Ready pod/api-test --timeout=120s
kubectl -n rbac-demo get pod api-test -o jsonpath='{.spec.serviceAccountName}{"\n"}'
```

**Expected result:** `viewer` — if this says `default`, the override did not apply and every
result below will be wrong.

Every pod gets its ServiceAccount token, CA and namespace mounted at
`/var/run/secrets/kubernetes.io/serviceaccount/`. Ask the API server directly and read the
HTTP status codes:

```bash
kubectl -n rbac-demo exec api-test -- sh -c '
SA=/var/run/secrets/kubernetes.io/serviceaccount
code() { curl -s -o /dev/null -w "%{http_code}" --cacert $SA/ca.crt \
  -H "Authorization: Bearer $(cat $SA/token)" "https://kubernetes.default.svc$1"; }
echo "list pods in rbac-demo   -> $(code /api/v1/namespaces/rbac-demo/pods)"
echo "list deploys in rbac-demo -> $(code /apis/apps/v1/namespaces/rbac-demo/deployments)"
echo "list pods in default      -> $(code /api/v1/namespaces/default/pods)"
echo "list nodes (cluster-wide) -> $(code /api/v1/nodes)"
'
```

**Expected result:**

```text
list pods in rbac-demo   -> 200
list deploys in rbac-demo -> 403
list pods in default      -> 403
list nodes (cluster-wide) -> 403
```

`200` is the Role working, `403` is RBAC refusing — authenticated but not authorised. A
`401` would mean the *token* was rejected, which is a different problem entirely.
