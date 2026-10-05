# Step 3 — Fault 2: targetPort mismatch

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
