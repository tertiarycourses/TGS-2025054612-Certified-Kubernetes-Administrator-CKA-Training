# Step 1 — Build a normal service

```bash
kubectl create deployment web --image=nginx --replicas=2
kubectl expose deploy web --port=80
kubectl run probe --image=nicolaka/netshoot --command -- sleep 3600
kubectl wait --for=condition=Ready pod/probe --timeout=60s
kubectl exec probe -- curl -s -o /dev/null -w "%{http_code}\n" http://web
```

**Expected result:** `200`. Establish the baseline before breaking anything — otherwise you
cannot tell your fault from a pre-existing one.
