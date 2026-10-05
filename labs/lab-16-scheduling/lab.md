# Lab 16 — Pod Scheduling (Limits, Affinity, Taints)

In this lab you control where pods land using resource requests, nodeSelector, node affinity, and taints/tolerations.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Label your nodes

Pick the **worker**, not the control plane. The control-plane node already carries a
`node-role.kubernetes.io/control-plane:NoSchedule` taint, so labelling it would make every
result below misleading:

```bash
kubectl get nodes --show-labels
NODE=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  -o jsonpath='{.items[0].metadata.name}')
echo "working with: $NODE"
kubectl label node $NODE disktype=ssd tier=frontend
kubectl get nodes -L disktype,tier
```

**Expected result:** `$NODE` is `node01` (or your worker's name), and the table shows
`disktype=ssd` and `tier=frontend` against it only.

> Keep this shell open — `$NODE` is used in Steps 6 and 7. A new tab starts without it.
> Check the control plane's taint for yourself:
> `kubectl get node -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].spec.taints}'`

---

## Step 2 — nodeSelector

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: ssd-pod }
spec:
  nodeSelector: { disktype: ssd }
  containers:
  - { name: app, image: nginx }
EOF
kubectl get pod ssd-pod -o wide
```

**Expected result:** `Running` on `$NODE` — the only node with `disktype=ssd`.

`nodeSelector` is a hard filter: no matching node means the pod stays `Pending` forever.
Try it:

```bash
kubectl run nowhere --image=nginx --overrides='{"spec":{"nodeSelector":{"disktype":"nvme"}}}'
kubectl get pod nowhere
kubectl describe pod nowhere | grep -A3 Events
```

**Expected result:** `Pending`, with
`0/2 nodes are available: 2 node(s) didn't match Pod's node affinity/selector`. Clean up:
`kubectl delete pod nowhere`.

---

## Step 3 — Node affinity (soft preference)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: affinity-pod }
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - { key: tier, operator: In, values: [frontend] }
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 50
        preference:
          matchExpressions:
          - { key: disktype, operator: In, values: [ssd] }
  containers:
  - { name: app, image: nginx }
EOF
kubectl get pod affinity-pod -o wide
```

**Expected result:** `Running` on `$NODE`, which satisfies the required `tier=frontend`
rule and also happens to match the preferred `disktype=ssd` hint.

`required…` behaves like `nodeSelector` but with richer operators (`In`, `NotIn`, `Exists`,
`Gt`, `Lt`). `preferred…` only ranks the candidates — if nothing matches, the pod still
schedules. That is the entire difference, and it is examinable.

---

## Step 4 — Pod anti-affinity (spread)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata: { name: spread }
spec:
  replicas: 2
  selector: { matchLabels: { app: spread } }
  template:
    metadata: { labels: { app: spread } }
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels: { app: spread }
            topologyKey: kubernetes.io/hostname
      containers:
      - { name: app, image: nginx }
EOF
kubectl get pods -l app=spread -o wide
kubectl describe pod -l app=spread | grep -A3 Events | tail -5
```

**Expected result on this playground: one pod `Running`, one pod `Pending`** — and that is
the lesson, not a failure. `requiredDuringScheduling` anti-affinity with
`topologyKey: kubernetes.io/hostname` permits at most one `app=spread` pod per node. Only
the worker is schedulable (the control plane is tainted), so the second replica has nowhere
to go and reports
`didn't match pod anti-affinity rules`.

In a real multi-node cluster the two would land on different nodes — which is exactly how
you spread replicas across failure domains. Swap `required` for
`preferredDuringSchedulingIgnoredDuringExecution` and the second pod schedules anyway,
sharing the node.

---

## Step 5 — Resource requests and limits

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: sized }
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests: { cpu: "100m", memory: "64Mi" }
      limits:   { cpu: "500m", memory: "128Mi" }
EOF
kubectl describe pod sized | grep -A5 -E "Limits|Requests"
kubectl get pod sized -o jsonpath='{.status.qosClass}{"\n"}'
```

**Expected result:** limits `cpu: 500m`, `memory: 128Mi`, requests `cpu: 100m`,
`memory: 64Mi`, and QoS class `Burstable` (requests set, but lower than limits).

The scheduler only considers **requests** when choosing a node; limits are enforced at
runtime by the kernel. See what the node has left:

```bash
kubectl describe node $NODE | grep -A6 "Allocated resources"
```

**Expected result:** a table of requests and limits as percentages of capacity. A pod whose
*request* exceeds what remains stays `Pending` — which is why over-requesting wastes a
cluster.

---

## Step 6 — Taints and tolerations

```bash
kubectl taint node $NODE workload=batch:NoSchedule
kubectl run notol --image=nginx
sleep 5
kubectl get pod notol -o wide
kubectl describe pod notol | grep -A3 Events
```

**Expected result:** `notol` is **`Pending`**. Both nodes now repel it — the control plane
with its own `NoSchedule` taint, and `$NODE` with the `workload=batch` taint you just
added. The event reads
`0/2 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 1 node(s) had untolerated taint {workload: batch}`.

A taint repels pods; a toleration is a pod saying "that one does not apply to me".

Add a toleration:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: tolerant }
spec:
  tolerations:
  - { key: workload, operator: Equal, value: batch, effect: NoSchedule }
  containers:
  - { name: app, image: nginx }
EOF
kubectl get pod tolerant -o wide
```

**Expected result:** `tolerant` is `Running` on `$NODE` — same cluster, same taint, but this
pod tolerates it.

> A toleration **permits**, it does not **attract**. `tolerant` could still have landed
> anywhere that accepted it; use `nodeSelector` or affinity when you need to *target* a
> node.

Remove the taint:

```bash
kubectl taint node $NODE workload-
```

---

## Step 7 — Cleanup

```bash
kubectl delete pod ssd-pod affinity-pod sized tolerant notol nowhere --ignore-not-found
kubectl delete deploy spread --ignore-not-found
kubectl label node $NODE disktype- tier-
kubectl taint node $NODE workload- 2>/dev/null || true
kubectl get nodes -L disktype,tier
kubectl describe node $NODE | grep -i taints
```

**Expected result:** the `disktype`/`tier` columns are empty and the worker's `Taints:` line
reads `<none>`. Leaving a stray taint behind is the most common way to break the *next*
lab.

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — labels | `$NODE` is the worker; `disktype=ssd`, `tier=frontend` on it only |
| Step 2 — nodeSelector | `ssd-pod` on `$NODE`; an unmatchable selector leaves a pod `Pending` |
| Step 3 — affinity | `affinity-pod` on `$NODE`; required filters, preferred only ranks |
| Step 4 — anti-affinity | one pod Running, one `Pending` with `didn't match pod anti-affinity rules` |
| Step 5 — requests/limits | QoS `Burstable`; node shows allocated requests |
| Step 6 — taints | `notol` `Pending` with untolerated-taint events; `tolerant` Running |
| Step 7 — cleanup | no custom labels, `Taints: <none>` on the worker |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `$NODE` is empty in a later step | A new shell lost the variable. Re-run the `NODE=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' …)` line. |
| Pods land on the control plane | You labelled the wrong node. Step 1 selects the worker deliberately. |
| Second `spread` replica stays `Pending` | Correct here: required anti-affinity allows one pod per node and only the worker is schedulable. |
| `notol` schedules instead of staying Pending | The control-plane taint was removed earlier. Check `kubectl describe node <cp> | grep -i taints`. |
| Everything `Pending` after this lab | A taint was left behind: `kubectl taint node <node> workload-`. |
| `error: at least one taint update is required` | The taint is already gone — the trailing `-` form removes it. |

---

## What you learned
- nodeSelector, node affinity, pod anti-affinity.
- Resource requests drive scheduling; limits cap runtime.
- Taints repel, tolerations let pods bypass them.
