# Lab 21 — Network Policies

NetworkPolicy is the Kubernetes firewall for pod-to-pod traffic. It requires a CNI that enforces policy (Calico, Cilium, Weave). In this lab you write deny-by-default, then progressively allow traffic.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Check your CNI enforces policy, then create the test pods

**Do this first.** A NetworkPolicy is only a *request*: the CNI plugin enforces it. Calico
and Cilium do; **Flannel does not** and ignores every policy silently — so the "blocked"
steps below would return `200` and teach you the opposite of the truth.

```bash
kubectl get pods -n kube-system -o name | grep -Ei 'calico|cilium|weave' || \
  echo "WARNING: no policy-enforcing CNI found - policies will be ignored"
ls /etc/cni/net.d/
```

**Expected result:** Calico or Cilium pods are listed. If you see the warning, or only
`flannel` in `/etc/cni/net.d/`, stop here and install Calico (Lab 3) — otherwise every
result in this lab is meaningless.

Now the test pods:

```bash
kubectl create ns netpol
kubectl -n netpol run server --image=nginx --labels="app=server"
kubectl -n netpol run client-ok --image=nicolaka/netshoot --labels="role=allowed" --command -- sleep 3600
kubectl -n netpol run client-bad --image=nicolaka/netshoot --labels="role=denied" --command -- sleep 3600
kubectl -n netpol expose pod server --port=80
kubectl -n netpol wait --for=condition=Ready pod --all --timeout=60s
```

---

## Step 2 — Baseline: everything allowed

```bash
kubectl -n netpol exec client-ok  -- curl -s -o /dev/null -w "%{http_code}\n" http://server
kubectl -n netpol exec client-bad -- curl -s -o /dev/null -w "%{http_code}\n" http://server
```

**Expected result:** `200` from both.

With no policy in the namespace, all pod-to-pod traffic is allowed — Kubernetes is
allow-by-default until the first policy selects a pod.

---

## Step 3 — Default-deny ingress

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny, namespace: netpol }
spec:
  podSelector: {}
  policyTypes: [Ingress]
EOF
```

Re-test:

```bash
kubectl -n netpol exec client-ok  -- curl -s --max-time 3 http://server || echo BLOCKED
kubectl -n netpol exec client-bad -- curl -s --max-time 3 http://server || echo BLOCKED
```

**Expected result:** `BLOCKED` twice, after a ~3 second timeout each.

Note *how* it fails: the request **times out** rather than being refused. A dropped packet
looks like a hang, which is why "my app is slow" is so often a NetworkPolicy problem.

`podSelector: {}` selects **every** pod in the namespace, and naming `Ingress` in
`policyTypes` with no `ingress:` rules means "allow nothing in". Egress is untouched —
these pods can still make outbound calls.

---

## Step 4 — Allow only the trusted client

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-trusted, namespace: netpol }
spec:
  podSelector: { matchLabels: { app: server } }
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector: { matchLabels: { role: allowed } }
    ports:
    - { protocol: TCP, port: 80 }
EOF
```

```bash
kubectl -n netpol exec client-ok  -- curl -s -o /dev/null -w "%{http_code}\n" http://server   # 200
kubectl -n netpol exec client-bad -- curl -s --max-time 3 http://server || echo BLOCKED
```

**Expected result:** `200` from `client-ok` and `BLOCKED` from `client-bad`.

Policies are **additive and never deny**: `default-deny` still exists, and this second
policy only adds an allowance. There is no ordering or priority in NetworkPolicy — the
union of all matching policies is what is permitted.

---

## Step 5 — Allow from another namespace

```bash
kubectl create ns trusted
kubectl label ns trusted purpose=trusted
kubectl -n trusted run remote --image=nicolaka/netshoot --command -- sleep 3600
kubectl -n trusted wait --for=condition=Ready pod/remote --timeout=60s

kubectl -n netpol patch networkpolicy allow-trusted --type=merge -p '{"spec":{"ingress":[{"from":[{"podSelector":{"matchLabels":{"role":"allowed"}}},{"namespaceSelector":{"matchLabels":{"purpose":"trusted"}}}],"ports":[{"protocol":"TCP","port":80}]}]}}'

kubectl -n netpol get networkpolicy allow-trusted -o jsonpath='{.spec.ingress[0].from}{"\n"}'
kubectl -n trusted exec remote -- curl -s -o /dev/null -w "%{http_code}\n" http://server.netpol.svc.cluster.local
kubectl -n netpol exec client-bad -- curl -s --max-time 3 http://server || echo "client-bad still BLOCKED"
```

**Expected result:** `200` from the `trusted` namespace, while `client-bad` in `netpol`
stays blocked.

> **Two list items, not one.** `from:` holds a list, and separate items are **OR**ed:
> "pods labelled `role=allowed`" *or* "anything in a namespace labelled
> `purpose=trusted`". Put `podSelector` and `namespaceSelector` under a **single** item and
> the meaning changes to AND — pods with that label *inside* that namespace. That is the
> most commonly mis-written NetworkPolicy in the exam.
>
> Use JSON for `--type=merge`: a YAML patch string works only sometimes.

---

## Step 6 — Egress policy

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: dns-only, namespace: netpol }
spec:
  podSelector: { matchLabels: { role: denied } }
  policyTypes: [Egress]
  egress:
  - to:
    - namespaceSelector: {}
      podSelector: { matchLabels: { k8s-app: kube-dns } }
    ports:
    - { protocol: UDP, port: 53 }
    - { protocol: TCP, port: 53 }
EOF
kubectl -n netpol exec client-bad -- curl -s --max-time 3 http://1.1.1.1 || echo BLOCKED
kubectl -n netpol exec client-bad -- nslookup kubernetes.default
```

**Expected result:** `BLOCKED` for the outbound HTTP call, but the DNS lookup still
answers with `kubernetes.default.svc.cluster.local` and a `10.96.0.1`-style address.

> **Always allow TCP/53 as well as UDP/53.** Resolvers fall back to TCP for large answers,
> and an egress policy with UDP only produces intermittent, maddening DNS failures. This
> is the single most common self-inflicted egress bug.
>
> Note the `to:` item combines `namespaceSelector: {}` (any namespace) with a
> `podSelector` in the **same** list item — AND, deliberately: only the kube-dns pods, in
> whichever namespace they live.

---

## Step 7 — Cleanup

```bash
kubectl delete ns netpol trusted
```

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — CNI check | Calico or Cilium pods listed — otherwise policies are ignored |
| Step 2 — baseline | `200` from both clients |
| Step 3 — default-deny | `BLOCKED` from both, by timeout |
| Step 4 — selective allow | `200` from `client-ok`, `BLOCKED` from `client-bad` |
| Step 5 — cross-namespace | `200` from the `trusted` namespace; `client-bad` still blocked |
| Step 6 — egress | outbound HTTP `BLOCKED`, DNS still resolves |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Everything returns `200` even after default-deny | Your CNI does not enforce policy (Flannel). Install Calico — see Step 1. |
| Requests hang instead of failing fast | Expected: denied packets are dropped, not refused. Use `--max-time`. |
| DNS breaks as soon as an egress policy exists | Allow both UDP **and** TCP on port 53, as Step 6 does. |
| `;; Got recursion not available from 10.96.0.10` | Cosmetic warning from `nslookup`, not a failure — CoreDNS does not advertise recursion to pods. |
| A cross-namespace allow does not work | The namespace needs the label the policy selects: `kubectl label ns trusted purpose=trusted`. |
| `podSelector` + `namespaceSelector` behave unexpectedly | Separate list items are OR; the same item is AND. Check with `kubectl get netpol <name> -o yaml`. |
| `kubectl patch` rejects the policy | Pass JSON with `--type=merge`, not a YAML string. |

---

## What you learned
- Default-deny + explicit-allow is the safe pattern.
- `podSelector`, `namespaceSelector`, port lists.
- Ingress and Egress are separate `policyTypes`.
