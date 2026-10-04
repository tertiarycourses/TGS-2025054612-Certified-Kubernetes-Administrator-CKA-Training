# Well done!

You have completed Lab 8 — RBAC: Roles, RoleBindings, ServiceAccounts:

✅ Created ServiceAccount `viewer`, Role `pod-viewer`, and the RoleBinding joining them
✅ Verified access with `kubectl auth can-i --as=system:serviceaccount:rbac-demo:viewer`,
   including the `default` namespace where it is denied
✅ Ran a pod **as** the ServiceAccount with `--overrides` and confirmed
   `spec.serviceAccountName`
✅ Called the API with the pod's mounted token: `200` for pods, `403` for Deployments
✅ Added a ClusterRole + ClusterRoleBinding and saw `nodes` change from `403` to `200` with
   no restart
✅ Inspected the aggregated `view` ClusterRole and bound it per namespace

**Next:** Lab 9 — CRDs and Operators
