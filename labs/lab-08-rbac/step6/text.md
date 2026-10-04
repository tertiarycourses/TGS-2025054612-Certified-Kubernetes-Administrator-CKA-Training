# Step 6 — ClusterRole and ClusterRoleBinding

Some resources are not in any namespace — nodes, PersistentVolumes, namespaces themselves.
Those need a `ClusterRole`, and a `ClusterRoleBinding` to grant it cluster-wide.

```bash
kubectl create clusterrole node-reader --verb=get,list,watch --resource=nodes
kubectl create clusterrolebinding viewer-nodes \
  --clusterrole=node-reader \
  --serviceaccount=rbac-demo:viewer
kubectl auth can-i list nodes --as=system:serviceaccount:rbac-demo:viewer
```

**Expected result:** `yes`.

Re-run the in-pod check and watch one line change:

```bash
kubectl -n rbac-demo exec api-test -- sh -c '
SA=/var/run/secrets/kubernetes.io/serviceaccount
curl -s -o /dev/null -w "nodes -> %{http_code}\n" --cacert $SA/ca.crt \
  -H "Authorization: Bearer $(cat $SA/token)" https://kubernetes.default.svc/api/v1/nodes'
```

**Expected result:** `nodes -> 200`, while listing Deployments is still `403`. Nothing was
restarted — RBAC is evaluated per request, so the new binding applied immediately.

> A `ClusterRole` bound with a **RoleBinding** instead grants its rules in that one
> namespace only. That pairing is how the built-in `view`/`edit` roles are usually handed
> out per team.
