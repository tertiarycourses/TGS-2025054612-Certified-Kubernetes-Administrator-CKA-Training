# Step 3 — ReplicaSet self-heal

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
