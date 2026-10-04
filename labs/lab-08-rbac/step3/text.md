# Step 3 — Bind the Role to the ServiceAccount

A Role grants nothing until something is bound to it.

```bash
kubectl -n rbac-demo create rolebinding viewer-binding \
  --role=pod-viewer \
  --serviceaccount=rbac-demo:viewer
kubectl -n rbac-demo get rolebinding viewer-binding -o wide
```

**Expected result:** the binding lists `Role/pod-viewer` and the subject
`rbac-demo/viewer`.

The identity format matters and is examinable: a ServiceAccount's username is
`system:serviceaccount:<namespace>:<name>`.
