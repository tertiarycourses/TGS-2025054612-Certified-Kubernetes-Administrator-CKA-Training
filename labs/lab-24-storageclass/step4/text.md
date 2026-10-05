# Step 4 — Create a PVC without specifying a class

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: data-pvc }
spec:
  accessModes: [ReadWriteOnce]
  resources: { requests: { storage: 200Mi } }
EOF
kubectl get pvc
kubectl get pv
```

**Expected result — and this surprises almost everyone:** the PVC is **`Pending`** and
there is **no PV at all**:

```text
NAME       STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS       AGE
data-pvc   Pending                                      local-path (default)  5s
```

```bash
kubectl describe pvc data-pvc | tail -5
```

**Expected result:** `waiting for first consumer to be created before binding`.

That is `WaitForFirstConsumer` doing its job, not a failure. A *local* volume must be
created on the node that will actually run the pod, so the provisioner waits for the
scheduler to choose one. Give it a consumer:

```bash
kubectl run user --image=busybox:1.36 --overrides='
{"spec":{"containers":[{"name":"user","image":"busybox:1.36","command":["sh","-c","echo written > /data/f; sleep 3600"],
"volumeMounts":[{"name":"d","mountPath":"/data"}]}],"volumes":[{"name":"d","persistentVolumeClaim":{"claimName":"data-pvc"}}]}}'
kubectl wait --for=condition=Ready pod/user --timeout=120s
kubectl get pvc data-pvc
kubectl get pv
kubectl exec user -- cat /data/f
```

**Expected result:** the PVC is now `Bound`, a PV named `pvc-<uuid>` exists with reclaim
policy `Delete`, and the file reads `written`. The PV was created *on demand*, which is the
whole point of dynamic provisioning.

> The other binding mode, `Immediate`, provisions as soon as the PVC is created — correct
> for network storage that any node can reach, wrong for local disks.
