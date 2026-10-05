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
