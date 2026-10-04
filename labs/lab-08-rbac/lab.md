# Lab 8 — RBAC: Roles, RoleBindings, ServiceAccounts

In this lab you build a read-only "viewer" identity: a ServiceAccount, a namespaced `Role`
allowing only `get/list/watch` on Pods, and the binding that joins them. Then you prove the
limits two ways — by impersonation, and from inside a pod using the ServiceAccount's own
token, where RBAC shows up as HTTP `200` and `403`.

**Lab environment:** [two-node playground](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node) ·
**Prerequisite:** a working cluster (`kubectl get nodes` responds)

---

## What you must be able to show

| Outcome | How you prove it |
|---|---|
| A Role grants nothing until bound | the RoleBinding in Step 3 |
| The identity format | `system:serviceaccount:rbac-demo:viewer` works with `--as` |
| Namespaced means namespaced | `can-i list pods` is `yes` in `rbac-demo`, `no` in `default` |
| RBAC is enforced on the real request path | in-pod `curl` returns `200` for pods, `403` for Deployments |
| Cluster-scoped needs a ClusterRole | `nodes` goes `403` → `200` after the ClusterRoleBinding, with no restart |
| Aggregated roles exist | `view` has an `aggregationRule` and covers more than your Role |

---

## Step 1 — Create a namespace and ServiceAccount

```bash
kubectl create ns rbac-demo
kubectl -n rbac-demo create serviceaccount viewer
kubectl -n rbac-demo get sa viewer
```

**Expected result:** ServiceAccount `viewer` exists. It has **no** permissions yet — a new
ServiceAccount can do nothing beyond unauthenticated discovery.

---

## Step 2 — Create a Role

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

---

## Step 3 — Bind the Role to the ServiceAccount

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

---

## Step 4 — Test with `kubectl auth can-i`

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

---

## Step 5 — Test from inside a pod, with the real token

Impersonation proves the rules; the token proves the **enforcement path**. Run a pod *as*
the ServiceAccount. `kubectl run` has no `--serviceaccount` flag, so set it through
`--overrides`:

```bash
kubectl -n rbac-demo run api-test \
  --image=curlimages/curl:8.11.1 \
  --overrides='{"spec":{"serviceAccountName":"viewer"}}' \
  --command -- sleep 3600
kubectl -n rbac-demo wait --for=condition=Ready pod/api-test --timeout=120s
kubectl -n rbac-demo get pod api-test -o jsonpath='{.spec.serviceAccountName}{"\n"}'
```

**Expected result:** `viewer` — if this says `default`, the override did not apply and every
result below will be wrong.

Every pod gets its ServiceAccount token, CA and namespace mounted at
`/var/run/secrets/kubernetes.io/serviceaccount/`. Ask the API server directly and read the
HTTP status codes:

```bash
kubectl -n rbac-demo exec api-test -- sh -c '
SA=/var/run/secrets/kubernetes.io/serviceaccount
code() { curl -s -o /dev/null -w "%{http_code}" --cacert $SA/ca.crt \
  -H "Authorization: Bearer $(cat $SA/token)" "https://kubernetes.default.svc$1"; }
echo "list pods in rbac-demo   -> $(code /api/v1/namespaces/rbac-demo/pods)"
echo "list deploys in rbac-demo -> $(code /apis/apps/v1/namespaces/rbac-demo/deployments)"
echo "list pods in default      -> $(code /api/v1/namespaces/default/pods)"
echo "list nodes (cluster-wide) -> $(code /api/v1/nodes)"
'
```

**Expected result:**

```text
list pods in rbac-demo   -> 200
list deploys in rbac-demo -> 403
list pods in default      -> 403
list nodes (cluster-wide) -> 403
```

`200` is the Role working, `403` is RBAC refusing — authenticated but not authorised. A
`401` would mean the *token* was rejected, which is a different problem entirely.

---

## Step 6 — ClusterRole and ClusterRoleBinding

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

---

## Step 7 — Aggregated ClusterRoles, and clean up

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

---

## Verification

| Check | Expected |
|---|---|
| Step 1 | ServiceAccount `viewer` created |
| Step 2 | rules show `pods` with `get/list/watch` in the core (`""`) group |
| Step 3 | RoleBinding links `Role/pod-viewer` to `rbac-demo/viewer` |
| Step 4 | `yes`, `no`, `no`, `no` |
| Step 5 | `spec.serviceAccountName` is `viewer`; codes are `200`, `403`, `403`, `403` |
| Step 6 | `can-i list nodes` → `yes`; in-pod `nodes -> 200`, Deployments still `403` |
| Step 7 | `view` has an `aggregationRule`; after binding it, `list deployments` → `yes` |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `unknown flag: --serviceaccount` | `kubectl run` has no such flag. Use `--overrides='{"spec":{"serviceAccountName":"viewer"}}'` as in Step 5. |
| `spec.serviceAccountName` says `default` | The `--overrides` JSON was malformed, so the pod ran with the default SA. Delete the pod and re-run. |
| Every in-pod call returns `403` | The pod is not using `viewer`, or the RoleBinding is missing: `kubectl -n rbac-demo get rolebinding -o wide`. |
| In-pod calls return `401` | The **token** was rejected, not the permissions — check you read `$SA/token` and passed `--cacert $SA/ca.crt`. |
| `ImagePullBackOff` on `api-test` | The image tag is unavailable. Try `curlimages/curl:latest`, or any image with a shell and `curl`. |
| `can-i` says `yes` but the pod gets `403` | You tested the wrong identity. `--as` must be the full `system:serviceaccount:<ns>:<name>`. |
| `error: failed to create clusterrolebinding … already exists` | Left over from an earlier run: `kubectl delete clusterrolebinding viewer-nodes` first. |

---

## What you learned
- The Role / RoleBinding / ClusterRole / ClusterRoleBinding split, and that a ClusterRole
  bound by a RoleBinding applies in one namespace only.
- The `system:serviceaccount:<ns>:<name>` identity format.
- `kubectl auth can-i --as=…` and `--list` for checking access without credentials.
- Where a pod's ServiceAccount token, CA and namespace are mounted, and how to call the API
  with them.
- That `403` means authenticated-but-refused while `401` means the token itself failed, and
  that RBAC changes take effect per request — no restart.
