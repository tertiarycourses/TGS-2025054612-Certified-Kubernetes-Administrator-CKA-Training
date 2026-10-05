# Step 2 — nodeSelector

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

The first `get pod` often shows `Pending` with no node assigned: scheduling and the image
pull take a few seconds. Re-run it, or wait explicitly:

```bash
kubectl wait --for=condition=Ready pod/ssd-pod --timeout=120s
kubectl get pod ssd-pod -o wide
```

`nodeSelector` is a hard filter: no matching node means the pod stays `Pending` forever.
Try it:

```bash
kubectl run nowhere --image=nginx --overrides='{"spec":{"nodeSelector":{"disktype":"nvme"}}}'
kubectl get pod nowhere
kubectl describe pod nowhere | grep -A3 Events
```

**Expected result:** `Pending`, with an event naming **both** nodes and why each refused:

```text
0/2 nodes are available: 1 node(s) didn't match Pod's node affinity/selector,
1 node(s) had untolerated taint(s). preemption: 0/2 nodes are available:
2 Preemption is not helpful for scheduling.
```

Read it carefully — the scheduler reports a *different* reason per node. The worker has
labels but not `disktype=nvme`; the control plane never got that far, because its
`NoSchedule` taint ruled it out first. The `preemption:` line means evicting lower-priority
pods would not help either, so the pod simply waits.

Clean up: `kubectl delete pod nowhere`.
