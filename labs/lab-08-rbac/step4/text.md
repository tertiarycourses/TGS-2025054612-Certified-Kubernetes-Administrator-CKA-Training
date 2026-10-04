# Step 4 — Test with `kubectl auth can-i`

`--as` impersonates another identity. You can do this because *you* are cluster-admin; it
answers "what could they do?" without logging in as them.

```bash
kubectl -n rbac-demo auth can-i list pods        --as=system:serviceaccount:rbac-demo:viewer
kubectl -n rbac-demo auth can-i create pods      --as=system:serviceaccount:rbac-demo:viewer
kubectl -n rbac-demo auth can-i list deployments --as=system:serviceaccount:rbac-demo:viewer
kubectl -n default   auth can-i list pods        --as=system:serviceaccount:rbac-demo:viewer
```

**Expected result:** `yes`, `no`, `no`, `no`.

The last one is the point of a namespaced Role: the same identity that can list Pods in
`rbac-demo` cannot list them in `default`.

A full picture of what the identity may do:

```bash
kubectl -n rbac-demo auth can-i --list --as=system:serviceaccount:rbac-demo:viewer | head
```
