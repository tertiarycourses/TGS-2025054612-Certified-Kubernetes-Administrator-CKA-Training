# Step 2 — Create a Role

A `Role` is namespaced: it can only grant rights inside its own namespace.

```bash
kubectl -n rbac-demo create role pod-viewer \
  --verb=get,list,watch \
  --resource=pods
kubectl -n rbac-demo get role pod-viewer -o yaml | grep -A6 "^rules:"
```

**Expected result:**

```yaml
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list
  - watch
```

`apiGroups: [""]` is the **core** group, where Pods, Services, ConfigMaps and Nodes live.
Deployments are in `apps`, which this Role does not mention — so they stay denied.
