# Lab 8 — RBAC: Roles, RoleBindings, ServiceAccounts

You will build a read-only "viewer" identity — a ServiceAccount, a namespaced `Role` for
`get/list/watch` on Pods, and the binding that joins them — then prove its limits by
impersonation **and** from inside a pod using the ServiceAccount's own token, where RBAC
appears as HTTP `200` and `403`.

**Prerequisite:** a working cluster (`kubectl get nodes`).

**What you will do:**
- Create a ServiceAccount, a Role, and a RoleBinding
- Check access with `kubectl auth can-i --as=…`, including a namespace where it is denied
- Run a pod as that ServiceAccount (`kubectl run` has no `--serviceaccount` flag — use
  `--overrides`) and call the API with its mounted token
- Grant a cluster-scoped permission with a ClusterRole and watch `nodes` go 403 → 200
- Inspect the aggregated `view` role and bind it instead of hand-writing rules
