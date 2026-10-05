# Lab 31 — Troubleshoot RBAC and Scheduling Failures

Two more high-frequency exam scenarios: a ServiceAccount that can't do what it needs, and a Pod that stays `Pending` because the scheduler refuses to place it.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Part A — RBAC

### Step 1 — Create a broken setup

```bash
kubectl create ns app
kubectl -n app create sa worker
kubectl -n app run worker-pod \
  --image=curlimages/curl:8.11.1 \
  --overrides='{"spec":{"serviceAccountName":"worker"}}' \
  --command -- sleep 3600
kubectl -n app wait --for=condition=Ready pod/worker-pod --timeout=120s
kubectl -n app get pod worker-pod -o jsonpath='{.spec.serviceAccountName}{"\n"}'
```

**Expected result:** `worker`. If it says `default`, the override did not apply and every
result below will be wrong — delete the pod and re-run.

Now ask the API server, as the ServiceAccount, using the token mounted in the pod:

```bash
kubectl -n app exec worker-pod -- sh -c '
SA=/var/run/secrets/kubernetes.io/serviceaccount
curl -s -o /dev/null -w "list pods -> %{http_code}\n" --cacert $SA/ca.crt \
  -H "Authorization: Bearer $(cat $SA/token)" \
  https://kubernetes.default.svc/api/v1/namespaces/app/pods'
```

**Expected result:** `list pods -> 403` — authenticated, but not authorised. A brand-new
ServiceAccount can do nothing.

> **Two traps avoided here.** `kubectl run` has **no** `--serviceaccount` flag — it must be
> set through `--overrides`. And the old `bitnami/kubectl` image comes from Bitnami's
> retired catalog: pinning a version now fails outright
> (`bitnami/kubectl:1.33.1` → 404). Calling the API with `curl` and the pod's own token
> needs no kubectl in the image, and shows RBAC as a plain HTTP status.

### Step 2 — Diagnose with `auth can-i`

```bash
kubectl -n app auth can-i list pods --as=system:serviceaccount:app:worker
kubectl -n app auth can-i --list --as=system:serviceaccount:app:worker | head -5
```

**Expected result:** `no`, and the `--list` output shows only the self-review permissions
every identity has.

`--as` impersonates — available because *you* are cluster-admin — and answers "what could
they do?" without a token. It is the fastest RBAC debugging tool there is, and it agrees
with the `403` you just saw from inside the pod.

### Step 3 — Grant minimal access

```bash
kubectl -n app create role pod-reader --verb=get,list,watch --resource=pods
kubectl -n app create rolebinding worker-reader --role=pod-reader --serviceaccount=app:worker
kubectl -n app auth can-i list pods --as=system:serviceaccount:app:worker
kubectl -n app exec worker-pod -- sh -c '
SA=/var/run/secrets/kubernetes.io/serviceaccount
curl -s -o /dev/null -w "list pods -> %{http_code}\n" --cacert $SA/ca.crt \
  -H "Authorization: Bearer $(cat $SA/token)" \
  https://kubernetes.default.svc/api/v1/namespaces/app/pods'
```

**Expected result:** `yes`, and `list pods -> 200`. No restart was needed — RBAC is
evaluated per request, so the binding takes effect immediately.

### Step 4 — Wrong scope (common trap)

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

---

## Part B — Scheduling failures

### Step 5 — Pending due to resources

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: hungry, namespace: app }
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests: { cpu: "100", memory: "100Gi" }
EOF
kubectl -n app get pod hungry
kubectl -n app describe pod hungry | grep -A5 Events
```

**Expected result:** `Pending`, with
`0/2 nodes are available: 2 Insufficient cpu, 2 Insufficient memory`.

Requests of `cpu: "100"` (100 whole cores) and `100Gi` cannot be met, and the scheduler
reports **why, per node**. Requests — not limits — drive scheduling, so an over-requested
pod never starts even on an idle cluster.

Fix:

```bash
kubectl -n app delete pod hungry
```

### Step 6 — Pending due to taint

Pick the **worker**: the control plane is already `NoSchedule`-tainted, so tainting it
would prove nothing — the pod would simply schedule on the worker.

```bash
NODE=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  -o jsonpath='{.items[0].metadata.name}')
echo "tainting: $NODE"
kubectl taint node $NODE dedicated=critical:NoSchedule
kubectl -n app run untol --image=nginx
sleep 5
kubectl -n app get pod untol
kubectl -n app describe pod untol | grep -A4 Events
```

**Expected result:** `Pending`, with both nodes rejecting it —
`1 node(s) had untolerated taint {dedicated: critical}` for the worker and
`{node-role.kubernetes.io/control-plane: }` for the control plane. With every node repelling
the pod, there is nowhere left to put it.

Fix:

```bash
kubectl taint node $NODE dedicated-
```

### Step 7 — Pending due to nodeSelector

```bash
kubectl -n app run picky --image=nginx \
  --overrides='{"spec":{"nodeSelector":{"zone":"never"}}}'
kubectl -n app describe pod picky | grep -A4 Events
```

**Expected result:** `Pending` with
`0/2 nodes are available: 2 node(s) didn't match Pod's node affinity/selector`.

Three different `Pending` causes, three different messages — resources, taints, selectors.
**`kubectl describe pod` Events names which one every time**, which is why it is the first
command for any `Pending` pod. Fix it by labelling a node or correcting the selector:

```bash
kubectl label node $NODE zone=never
sleep 5
kubectl -n app get pod picky -o wide
```

**Expected result:** `picky` now schedules — unless the taint from Step 6 is still in place,
in which case the event changes to the taint message. Clean up the label:
`kubectl label node $NODE zone-`.

### Step 8 — Cleanup

```bash
kubectl delete ns app
kubectl delete clusterrole node-reader
kubectl delete clusterrolebinding worker-nodes
kubectl taint node $NODE dedicated- 2>/dev/null || true
kubectl label node $NODE zone- 2>/dev/null || true
kubectl describe node $NODE | grep -i taints
```

**Expected result:** `Taints: <none>` on the worker. **Leaving the taint behind is the most
common way to break the next lab** — everything you create afterwards sits `Pending` for no
visible reason.

---

## Triage cheat sheet

| Symptom                                | First command                                                   |
|----------------------------------------|------------------------------------------------------------------|
| `forbidden`                            | `kubectl auth can-i <verb> <resource> --as=<sa>`                 |
| Pod `Pending`                          | `kubectl describe pod <name>` (read **Events**)                  |
| `Insufficient cpu/memory`              | `kubectl top nodes`, lower `resources.requests`                  |
| `untolerated taint`                    | `kubectl describe node | grep Taints`, add toleration or remove taint |
| `didn't match Pod's node affinity`     | Check labels: `kubectl get nodes --show-labels`                  |
| `pod has unbound immediate PVCs`       | `kubectl get pvc` → make sure StorageClass exists                |

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — broken setup | `spec.serviceAccountName` is `worker`; `list pods -> 403` |
| Step 2 — diagnosis | `can-i` says `no`, agreeing with the 403 |
| Step 3 — Role granted | `yes` and `list pods -> 200`, with no restart |
| Step 4 — cluster scope | `list nodes` goes 403 → 200 after the ClusterRoleBinding |
| Step 5 — Pending: resources | `Insufficient cpu, Insufficient memory` per node |
| Step 6 — Pending: taint | untolerated taint on both nodes |
| Step 7 — Pending: selector | `didn't match Pod's node affinity/selector` |
| Step 8 — cleanup | `Taints: <none>` on the worker |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `unknown flag: --serviceaccount` | `kubectl run` has no such flag — use `--overrides='{"spec":{"serviceAccountName":"worker"}}'`. |
| `ImagePullBackOff` on `worker-pod` | Bitnami images are retired; this lab uses `curlimages/curl`. |
| Every API call returns 403 even after Step 3 | The pod is not using the `worker` SA — check `spec.serviceAccountName`. |
| API call returns 401 | The token was rejected, not the permissions: read `$SA/token` and pass `--cacert $SA/ca.crt`. |
| `untol` schedules instead of staying Pending | You tainted the control plane, which was already tainted. Target the worker as Step 6 does. |
| Pods stay `Pending` after this lab | A taint or label was left behind: `kubectl taint node <node> dedicated-`. |
| `can-i` says yes but the pod gets 403 | You impersonated a different identity — use the full `system:serviceaccount:app:worker`. |

---

## What you learned
- Use `kubectl auth can-i --as=` to confirm RBAC outcomes before deployment.
- `describe pod` Events tells you exactly why scheduling failed.
- Role/RoleBinding for namespaced resources; ClusterRole/ClusterRoleBinding for cluster-scoped.
