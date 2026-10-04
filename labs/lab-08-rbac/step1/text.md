# Step 1 — Create a namespace and ServiceAccount

```bash
kubectl create ns rbac-demo
kubectl -n rbac-demo create serviceaccount viewer
kubectl -n rbac-demo get sa viewer
```

**Expected result:** ServiceAccount `viewer` exists. It has **no** permissions yet — a new
ServiceAccount can do nothing beyond unauthenticated discovery.
