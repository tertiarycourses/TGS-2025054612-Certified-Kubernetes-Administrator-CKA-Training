# Step 4 — Wrong scope (common trap)

```bash
kubectl -n app exec worker-pod -- sh -c '
SA=/var/run/secrets/kubernetes.io/serviceaccount
curl -s -o /dev/null -w "list nodes -> %{http_code}\n" --cacert $SA/ca.crt \
  -H "Authorization: Bearer $(cat $SA/token)" https://kubernetes.default.svc/api/v1/nodes'
```

**Expected result:** `list nodes -> 403`, even though pods now work.

Nodes are **cluster-scoped**: no namespaced Role can ever grant them, so this needs a
ClusterRole *and* a ClusterRoleBinding:

```bash
kubectl create clusterrole node-reader --verb=get,list,watch --resource=nodes
kubectl create clusterrolebinding worker-nodes --clusterrole=node-reader --serviceaccount=app:worker
kubectl -n app exec worker-pod -- sh -c '
SA=/var/run/secrets/kubernetes.io/serviceaccount
curl -s -o /dev/null -w "list nodes -> %{http_code}\n" --cacert $SA/ca.crt \
  -H "Authorization: Bearer $(cat $SA/token)" https://kubernetes.default.svc/api/v1/nodes'
```

**Expected result:** `list nodes -> 200`.

> Binding a **ClusterRole** with a **RoleBinding** grants its rules in that one namespace
> only — useful for the built-in `view`/`edit` roles, and useless for nodes, which belong to
> no namespace.
