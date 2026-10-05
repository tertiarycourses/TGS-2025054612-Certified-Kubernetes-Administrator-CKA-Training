# Lab 30 — Troubleshoot Services and Networking

Service connectivity bugs are the single biggest category of CKA exam questions. In this lab you walk the chain Pod → Service → DNS → Endpoint and fix three intentional faults.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Build a normal service

```bash
kubectl create deployment web --image=nginx --replicas=2
kubectl expose deploy web --port=80
kubectl run probe --image=nicolaka/netshoot --command -- sleep 3600
kubectl wait --for=condition=Ready pod/probe --timeout=60s
kubectl exec probe -- curl -s -o /dev/null -w "%{http_code}\n" http://web
```

**Expected result:** `200`. Establish the baseline before breaking anything — otherwise you
cannot tell your fault from a pre-existing one.

---

## Step 2 — Fault 1: selector mismatch

```bash
kubectl patch svc web --type=merge -p '{"spec":{"selector":{"app":"wrong"}}}'
kubectl exec probe -- curl -s --max-time 3 http://web || echo TIMEOUT
kubectl get endpointslices -l kubernetes.io/service-name=web
```

**Expected result:** `TIMEOUT`, and the EndpointSlice has **no addresses** (or none ready).
The Service still exists and DNS still resolves — it simply points at nothing, so the
connection hangs until the timeout.

```bash
kubectl get svc web -o jsonpath='{.spec.selector}{"\n"}'
kubectl get pods -l app=web --show-labels
```

**Expected result:** the selector says `{"app":"wrong"}` while the pods are labelled
`app=web`. **An empty endpoint list always means selector-versus-label**, and it is the
single most common Service bug.

Fix:

```bash
kubectl patch svc web --type=merge -p '{"spec":{"selector":{"app":"web"}}}'
kubectl get endpointslices -l kubernetes.io/service-name=web \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{"\n"}{end}'
```

**Expected result:** two pod IPs listed again.

> `kubectl get endpoints` still works but the Endpoints API is **deprecated since v1.33** —
> read EndpointSlices on a modern cluster.

---

## Step 3 — Fault 2: targetPort mismatch

```bash
kubectl patch svc web --type=merge -p '{"spec":{"ports":[{"port":80,"targetPort":8080}]}}'
kubectl exec probe -- curl -s --max-time 3 http://web || echo FAIL
```

Endpoints are populated, but the wrong port — connection refused.

```bash
kubectl describe svc web | grep -E "Port:|TargetPort"
kubectl exec probe -- curl -s -o /dev/null -w "%{http_code}\n" http://$(kubectl get pod -l app=web -o jsonpath='{.items[0].status.podIP}'):80
```

**Expected result:** `FAIL` through the Service, `TargetPort: 8080/TCP` in the description,
but `200` straight to the pod on port 80.

That pairing is the diagnosis: **endpoints exist and the pod answers, so the Service's
`targetPort` is wrong.** Compare it with the container's port:

```bash
kubectl get pod -l app=web -o jsonpath='{.items[0].spec.containers[0].ports}{"\n"}'
```

Unlike a selector mismatch, this fails *fast* — the packet reaches the pod and nothing is
listening on 8080, so it is refused rather than dropped.

Fix:

```bash
kubectl patch svc web --type=merge -p '{"spec":{"ports":[{"port":80,"targetPort":80}]}}'
```

---

## Step 4 — Fault 3: CoreDNS or resolv.conf

Simulate a busted DNS by scaling CoreDNS to zero:

```bash
kubectl -n kube-system scale deploy coredns --replicas=0
kubectl exec probe -- nslookup web 2>&1 | head -5
kubectl exec probe -- curl -s --max-time 3 http://web || echo DNS_DEAD
# pod IP still works
kubectl exec probe -- curl -s -o /dev/null -w "%{http_code}\n" \
  http://$(kubectl get pod -l app=web -o jsonpath='{.items[0].status.podIP}')
```

**Expected result:** `nslookup web` fails with a server-not-reached error, the Service
name times out (`DNS_DEAD`), **but the pod IP still returns `200`**.

That last line is the whole lesson: when names fail and IPs work, the problem is DNS — not
the Service, not the pods, not the network. Checking a pod IP directly takes five seconds
and eliminates most of the chain.

Restore:

```bash
kubectl -n kube-system scale deploy coredns --replicas=2
kubectl -n kube-system rollout status deploy coredns
kubectl exec probe -- curl -s -o /dev/null -w "%{http_code}\n" http://web
```

**Expected result:** `200` again once CoreDNS is back.

---

## Step 5 — The triage chain

When `curl <svc>` fails inside a pod:

```bash
# 1) Does DNS resolve?
kubectl exec probe -- nslookup web

# 2) Does the Service have endpoints?
kubectl get endpointslices -l kubernetes.io/service-name=web

# 3) Does the pod match the selector?
kubectl get pods --show-labels -l app=web

# 4) Does the targetPort match the container?
kubectl describe svc web | grep -E "Port|TargetPort"
kubectl get pod -l app=web -o jsonpath='{.items[0].spec.containers[0].ports[*].containerPort}{"\n"}'

# 5) Pod IP reachable from probe?
kubectl exec probe -- curl --max-time 3 http://$(kubectl get pod -l app=web -o jsonpath='{.items[0].status.podIP}'):80

# 6) NetworkPolicy blocking?
kubectl get networkpolicy -A

# 7) kube-proxy alive?
kubectl -n kube-system get pods -l k8s-app=kube-proxy
```

---

## Step 6 — Cleanup

```bash
kubectl delete deploy web
kubectl delete svc web
kubectl delete pod probe
```

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — baseline | `200` through the Service |
| Step 2 — selector mismatch | `TIMEOUT` and an empty endpoint list; selector vs labels differ |
| Step 3 — targetPort mismatch | `FAIL` via the Service but `200` direct to the pod |
| Step 4 — DNS down | name resolution fails, pod IP still `200`, recovers with CoreDNS |
| Step 5 — triage chain | you can run the seven checks in order from memory |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Endpoint list is empty | Selector/label mismatch: compare `svc -o jsonpath='{.spec.selector}'` with `get pods --show-labels`. |
| Connection hangs vs refused | Hang = dropped (no endpoints, or NetworkPolicy); refused = reached the pod, wrong port. |
| Name fails but pod IP works | DNS. Check CoreDNS pods and the pod's `/etc/resolv.conf`. |
| `;; Got recursion not available from 10.96.0.10` | Cosmetic warning from `nslookup`, not a failure — CoreDNS does not advertise recursion to pods. |
| Endpoints exist but traffic still fails | Check `targetPort` against the container port, then NetworkPolicies. |
| `kubectl get endpoints` prints a deprecation warning | Expected on v1.33+; use `endpointslices`. |
| Everything looks right and still fails | Check kube-proxy: `kubectl -n kube-system get pods -l k8s-app=kube-proxy` and its logs. |

---

## What you learned
- The seven-step triage chain from DNS to kube-proxy.
- `kubectl get endpoints` is the single most useful Service-debug command.
- CoreDNS failure looks like everything else broken — verify DNS first.
