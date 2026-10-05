# Step 4 — Fault 3: CoreDNS or resolv.conf

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
