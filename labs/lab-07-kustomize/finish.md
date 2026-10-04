# Well done!

You have completed Lab 7 — Customize Manifests with Kustomize:

✅ Built a base that renders on its own — no namespace, `replicas: 1`, `nginx:1.25`
✅ Added dev (`web-dev`, 1 replica, `1.25`) and prod (`web-prod`, 4 replicas, `1.27`)
   overlays from that one base
✅ Rendered with `kubectl kustomize` before applying with `kubectl apply -k`
✅ Proved both environments differ with a single `jsonpath` comparison
✅ Swapped a JSON 6902 patch for a strategic-merge patch and saw `2/2`

**Next:** Lab 8 — RBAC: Roles, RoleBindings, ServiceAccounts
