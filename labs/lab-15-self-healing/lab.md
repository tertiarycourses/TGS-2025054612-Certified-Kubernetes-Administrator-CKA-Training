# Lab 15 — Self-Healing Primitives

Kubernetes self-healing relies on four pillars: liveness/readiness/startup probes, ReplicaSets, DaemonSets, and StatefulSets. In this lab you exercise each one.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Liveness probe

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: live-demo }
spec:
  containers:
  - name: app
    image: busybox
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm /tmp/healthy; sleep 600
    livenessProbe:
      exec: { command: ["cat","/tmp/healthy"] }
      initialDelaySeconds: 5
      periodSeconds: 5
EOF
kubectl get pod live-demo -w
```

**Expected result:** the pod is `Running` for about 35 seconds, then `RESTARTS` increments
to `1`, and keeps climbing roughly every 35-40 seconds. Press Ctrl-C to stop watching.

The container deleted its own health file, so `cat /tmp/healthy` started failing. Read the
kubelet's own words:

```bash
kubectl describe pod live-demo | grep -A5 Events
```

**Expected result:** `Liveness probe failed: cat: can't open '/tmp/healthy'` followed by
`Container app failed liveness probe, will be restarted`.

> **Liveness restarts the container, it does not reschedule the pod.** The pod keeps its
> name, IP and node — only the container inside is recreated, which is why `RESTARTS` is a
> per-container counter.

---

## Step 2 — Readiness probe

```bash
kubectl run ready-demo --image=nginx \
  --overrides='{"spec":{"containers":[{"name":"ready-demo","image":"nginx","readinessProbe":{"httpGet":{"path":"/","port":80},"initialDelaySeconds":3,"periodSeconds":3}}]}}'
kubectl get pod ready-demo -w
```

**Expected result:** `READY` is `0/1` for the first few seconds, then `1/1` once the HTTP
probe succeeds. Ctrl-C to stop.

Readiness decides **traffic**, not restarts. Prove it with a Service:

```bash
kubectl expose pod ready-demo --port=80 --name=ready-svc
kubectl get endpointslices -l kubernetes.io/service-name=ready-svc \
  -o jsonpath='{.items[0].endpoints[0].conditions.ready}{"\n"}'
```

**Expected result:** `true` — the pod is in the Service's endpoints because it is *ready*.
A failing readiness probe would set this to `false` and remove the pod from load balancing
**without** restarting it. That is the whole difference from liveness.

```bash
kubectl delete svc ready-svc
```

---

## Step 3 — ReplicaSet self-heal

```bash
kubectl create deployment rs-demo --image=nginx --replicas=3
kubectl get pods -l app=rs-demo
POD=$(kubectl get pods -l app=rs-demo -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD
kubectl get pods -l app=rs-demo -w
```

**Expected result:** the deleted pod disappears and a **new** pod with a different name
appears within seconds, back to three. Ctrl-C to stop watching.

```bash
kubectl get rs -l app=rs-demo
kubectl describe rs -l app=rs-demo | grep -A3 Events
```

**Expected result:** the ReplicaSet reports `DESIRED 3 CURRENT 3 READY 3`, and its events
include `Created pod: rs-demo-...`. The ReplicaSet controller reconciles desired against
actual continuously — nobody told it to replace that pod.

---

## Step 4 — DaemonSet (one pod per node)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata: { name: log-agent, namespace: kube-system }
spec:
  selector: { matchLabels: { app: log-agent } }
  template:
    metadata: { labels: { app: log-agent } }
    spec:
      tolerations:
      - operator: Exists
      containers:
      - name: agent
        image: busybox
        command: ["sh","-c","while true; do echo log; sleep 60; done"]
EOF
kubectl -n kube-system get ds log-agent
kubectl -n kube-system get pods -l app=log-agent -o wide
```

**Expected result:** `DESIRED 2  CURRENT 2  READY 2` on a two-node cluster, and the pods sit
on **different** nodes — one per node, including the control plane thanks to
`tolerations: [{operator: Exists}]`, which tolerates every taint.

```bash
kubectl -n kube-system get pods -l app=log-agent \
  -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}'
```

**Expected result:** both node names, each once. A DaemonSet has no `replicas` field —
its count *is* the number of matching nodes, so adding a node adds a pod automatically.

---

## Step 5 — StatefulSet (stable identity)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata: { name: web-headless }
spec:
  clusterIP: None
  selector: { app: web-ss }
  ports: [{ port: 80 }]
---
apiVersion: apps/v1
kind: StatefulSet
metadata: { name: web-ss }
spec:
  serviceName: web-headless
  replicas: 3
  selector: { matchLabels: { app: web-ss } }
  template:
    metadata: { labels: { app: web-ss } }
    spec:
      containers:
      - name: nginx
        image: nginx
        ports: [{ containerPort: 80 }]
EOF
kubectl rollout status statefulset/web-ss
kubectl get pods -l app=web-ss
```

**Expected result:** exactly `web-ss-0`, `web-ss-1`, `web-ss-2` — **ordinal names, created
in order**, unlike a Deployment's random suffixes. Each gets a DNS A record from the
headless Service:

```bash
kubectl run dnstest --image=busybox:1.36 --rm -it --restart=Never -- \
  nslookup web-ss-0.web-headless.default.svc.cluster.local
```

**Expected result:** the lookup returns `web-ss-0`'s pod IP. Delete `web-ss-1` and it comes
back with the *same name* and the same DNS record — that is the stable identity a database
replica needs.

> **This StatefulSet has no storage.** Stable per-pod volumes need
> `volumeClaimTemplates`, which needs a StorageClass this cluster does not have yet —
> that is Labs 23-25. Identity and storage are separate guarantees; this step demonstrates
> identity only.

---

## Step 6 — Cleanup

```bash
kubectl delete pod live-demo ready-demo
kubectl delete deploy rs-demo
kubectl -n kube-system delete ds log-agent
kubectl delete statefulset web-ss
kubectl delete svc web-headless
kubectl delete pod dnstest --ignore-not-found
```

**Expected result:** everything removed. Deleting a StatefulSet leaves any PVCs behind by
design — there are none here, but remember it for Labs 23-25.

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — liveness | `RESTARTS` climbs; events show `Liveness probe failed` |
| Step 2 — readiness | `0/1` then `1/1`; the endpoint's `ready` condition is `true` |
| Step 3 — ReplicaSet | a replacement pod with a new name appears within seconds |
| Step 4 — DaemonSet | one pod per node, on different nodes |
| Step 5 — StatefulSet | `web-ss-0/1/2` in order; DNS resolves `web-ss-0.web-headless` |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `RESTARTS` stays 0 | The probe has not failed yet — the demo needs ~35s. `kubectl describe pod live-demo` shows probe events. |
| Pod goes `CrashLoopBackOff` | Expected eventually: repeated liveness failures back off exponentially. |
| Readiness pod never reaches `1/1` | The probe path or port is wrong: `kubectl describe pod ready-demo` shows `Readiness probe failed`. |
| DaemonSet shows only one pod | A node is unschedulable or the taint is not tolerated. `kubectl get nodes` and check `tolerations`. |
| StatefulSet pods stuck at `web-ss-0` | StatefulSets start pods **in order**: pod 0 must be Ready before pod 1 is created. |
| `nslookup` fails inside `dnstest` | Use the full name `web-ss-0.web-headless.default.svc.cluster.local`, and check CoreDNS is running. |

---

## What you learned
- Liveness restarts, readiness gates traffic, startup protects slow-boot apps.
- ReplicaSet, DaemonSet, StatefulSet — three different "shape" controllers.
- Headless Service + StatefulSet gives stable network identity.
