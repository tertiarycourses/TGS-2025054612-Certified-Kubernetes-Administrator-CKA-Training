# Step 7 — Aggregated ClusterRoles, and clean up

The built-in `view`, `edit` and `admin` roles are **aggregated**: the control plane fills
their rules from every ClusterRole carrying a matching label, which is how CRDs add
themselves to `view` automatically.

```bash
kubectl get clusterrole view -o jsonpath='{.aggregationRule}{"\n"}'
kubectl describe clusterrole view | head -20
```

**Expected result:** an `aggregationRule` selecting
`rbac.authorization.k8s.io/aggregate-to-view: "true"`, then a long rules list it did not
define itself.

Grant the real thing instead of hand-writing rules:

```bash
kubectl -n rbac-demo create rolebinding viewer-readonly \
  --clusterrole=view --serviceaccount=rbac-demo:viewer
kubectl -n rbac-demo auth can-i list deployments --as=system:serviceaccount:rbac-demo:viewer
```

**Expected result:** now `yes` — `view` covers Deployments, which your narrow `pod-viewer`
Role deliberately did not.

Clean up:

```bash
kubectl delete ns rbac-demo
kubectl delete clusterrolebinding viewer-nodes
kubectl delete clusterrole node-reader
```
