# Lab 14 — Horizontal Pod Autoscaling

The Horizontal Pod Autoscaler (HPA) scales a Deployment up and down based on observed CPU/memory or custom metrics. In this lab you install `metrics-server`, deploy a CPU-burning app, attach an HPA, then stress it.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Install metrics-server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deploy metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s
```

Metrics are **not** available the moment the pod is ready — the API needs a scrape cycle
first. Wait for it instead of guessing:

```bash
until kubectl top nodes > /dev/null 2>&1; do echo "waiting for metrics..."; sleep 10; done
kubectl top nodes
kubectl top pods -A | head
```

**Expected result:** after up to a minute, `top nodes` prints CPU and memory for both nodes.
Until then it fails with `error: Metrics API not available` — that is the API registering,
not a broken install.

`--kubelet-insecure-tls` is needed in lab environments where the kubelet serves a
self-signed certificate; without it metrics-server logs `x509: cannot validate certificate`
and never becomes ready.

---

## Step 2 — Deploy a CPU-bound workload

```bash
kubectl create deployment php-apache --image=registry.k8s.io/hpa-example
kubectl set resources deploy/php-apache --requests=cpu=100m --limits=cpu=500m
kubectl expose deployment php-apache --port=80
kubectl rollout status deploy/php-apache
```

**Expected result:** `successfully rolled out`, one pod Running.

The `--requests=cpu=100m` is **mandatory**, not decoration: HPA computes utilisation as
*usage ÷ request*. With no request there is nothing to divide by, and the HPA reports
`<unknown>` forever.

---

## Step 3 — Create the HPA

```bash
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=5
kubectl get hpa
```

**Expected result:** at first `TARGETS` reads `<unknown>/50%`. That is normal for the first
15-30 seconds, until the HPA controller has a metrics sample. Wait for a real number:

```bash
until kubectl get hpa php-apache -o jsonpath='{.status.currentMetrics}' | grep -q averageUtilization; do
  sleep 10; echo "waiting for the first metric..."
done
kubectl get hpa php-apache
```

**Expected result:** `TARGETS` becomes something like `0%/50%` with `REPLICAS 1`. If it
stays `<unknown>` for minutes, the Deployment has no CPU **request** (Step 2) or
metrics-server is not serving (Step 1).

---

## Step 4 — Generate load

In a new terminal:

```bash
kubectl run -i --tty load --image=busybox --restart=Never -- /bin/sh -c \
  "while true; do wget -q -O- http://php-apache; done"
```

Watch:

```bash
kubectl get hpa -w
```

**Expected result:** within a minute `TARGETS` climbs well past `50%` (often several hundred
per cent, since one busy pod can use many times its 100m request), and `REPLICAS` rises
step by step toward `5`. Scale-**up** decisions are made about every 15 seconds.

```bash
kubectl get pods -l app=php-apache
kubectl top pods -l app=php-apache
```

**Expected result:** up to five pods. On a 1-CPU playground some may stay `Pending` for lack
of CPU — the HPA's *desired* count still rises, which is what you are observing. The load
generator competes for the same single CPU, so numbers swing; that is the environment, not
the HPA.

---

## Step 5 — Stop the load and watch scale-down

Ctrl-C the load generator (or open a second tab), then:

```bash
kubectl delete pod load --ignore-not-found
kubectl get hpa -w
```

**Expected result:** `TARGETS` drops to `0%/50%` within a minute, but `REPLICAS` stays high
for about **5 minutes** before returning to `1`.

That delay is the scale-down **stabilisation window**
(`--horizontal-pod-autoscaler-downscale-stabilization`, default 300s): the HPA takes the
highest recommendation from the last 5 minutes so a brief dip cannot cause flapping.
Scale-up has no such window, which is why up is fast and down is slow. Press Ctrl-C when
you have seen `REPLICAS 1`.

---

## Step 6 — HPA v2 with multiple metrics (reference)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: { name: php-apache }
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target: { type: Utilization, averageUtilization: 50 }
  - type: Resource
    resource:
      name: memory
      target: { type: AverageValue, averageValue: 200Mi }
```

---

## Step 7 — Cleanup

```bash
kubectl delete hpa php-apache
kubectl delete deploy php-apache
kubectl delete svc php-apache
```

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — metrics-server | `kubectl top nodes` prints CPU/memory for both nodes |
| Step 2 — workload | one `php-apache` pod Running **with** a CPU request |
| Step 3 — HPA created | `TARGETS` moves from `<unknown>/50%` to a real percentage |
| Step 4 — load | `TARGETS` exceeds 50% and `REPLICAS` rises toward 5 |
| Step 5 — scale-down | `TARGETS` back to `0%`, `REPLICAS` returns to 1 after ~5 minutes |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `error: Metrics API not available` | metrics-server has not completed a scrape yet. Use the wait loop in Step 1. |
| metrics-server never becomes Ready | Missing `--kubelet-insecure-tls`; its log shows `x509: cannot validate certificate`. |
| `TARGETS` stays `<unknown>/50%` | The target Deployment has no `resources.requests.cpu`, so utilisation cannot be computed. |
| Replicas never rise | The load generator is not reaching the Service: `kubectl exec load -- wget -qO- http://php-apache` from another tab. |
| New pods stay `Pending` | Not enough CPU on a 1-CPU node. The HPA's desired count is still the lesson; `describe pod` shows `Insufficient cpu`. |
| Scale-down looks stuck | Expected for ~5 minutes — the downscale stabilisation window. |

---

## What you learned
- metrics-server is a prerequisite for `kubectl top` and HPA.
- HPA needs `resources.requests` on the target Deployment.
- Stabilization window prevents flapping.
