# Lab 23 — PersistentVolume and PersistentVolumeClaim

A PersistentVolume (PV) is a piece of storage in the cluster. A PersistentVolumeClaim (PVC) is a pod's request for storage. In this lab you statically provision a `hostPath` PV, claim it, mount it, and explore access modes and reclaim policies.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Prepare a host directory on the node that will run the pod

`hostPath` reads a directory **on one specific node**. The control plane is tainted, so
your pod will land on the worker — create the directory *there*, or the pod mounts an empty
directory and the check in Step 4 fails.

```bash
TARGET=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  -o jsonpath='{.items[0].metadata.name}')
echo "pod will run on: $TARGET"
ssh $TARGET "sudo mkdir -p /mnt/data && echo 'hello from host' | sudo tee /mnt/data/index.html"
```

**Expected result:** `hello from host` echoed back from the worker node.

> On the KillerCoda two-node playground `ssh node01` works from the control plane without a
> password. If you only have one node, run the commands locally without `ssh` — `$TARGET`
> is then the control plane itself.

---

## Step 2 — Create a PV

Note the heredoc below is unquoted (`<<EOF`, not `<<'EOF'`) so the shell substitutes
`$TARGET` from Step 1 as the PV is created — a PV's `nodeAffinity` is **immutable
afterwards**, so it has to be right the first time:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-host
spec:
  capacity: { storage: 1Gi }
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath: { path: /mnt/data }
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: ["$TARGET"]
EOF
kubectl get pv pv-host
kubectl get pv pv-host -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values}{"\n"}'
```

**Expected result:** the PV is `Available` with capacity `1Gi`, `RWO`, reclaim policy
`Retain`, and its node affinity names your worker.

> **Why node affinity on a local volume?** Without it the scheduler may place the pod on a
> node where `/mnt/data` does not exist — the mount then silently succeeds against an empty
> directory. This is the same mechanism `local` volumes use, and the reason `hostPath` is
> unsuitable for real workloads.

Access modes:
- **ReadWriteOnce (RWO)** — one node, read-write
- **ReadOnlyMany (ROX)** — many nodes, read-only
- **ReadWriteMany (RWX)** — many nodes, read-write (needs NFS/CephFS-class storage)
- **ReadWriteOncePod (RWOP)** — one pod, read-write

Reclaim policies:
- **Retain** — keep data after PVC deletion (manual cleanup)
- **Delete** — remove the volume (dynamic provisioning default)
- **Recycle** — deprecated

---

## Step 3 — Create a PVC

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: pvc-host }
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: manual
  resources: { requests: { storage: 500Mi } }
EOF
kubectl get pvc pvc-host
kubectl get pv pv-host
```

**Expected result:** the PVC is `Bound` to `pv-host`, and the PV's status flips from
`Available` to `Bound` with `CLAIM default/pvc-host`.

Binding needs **all** of: the same `storageClassName`, a compatible access mode, and a PV
at least as large as the request. Note the PVC asked for `500Mi` and got the whole `1Gi`
volume — static PVs are never split.

---

## Step 4 — Mount in a Pod

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: web }
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - { name: data, mountPath: /usr/share/nginx/html }
  volumes:
  - name: data
    persistentVolumeClaim: { claimName: pvc-host }
EOF
kubectl wait --for=condition=Ready pod/web --timeout=60s
kubectl get pod web -o wide
kubectl exec web -- curl -s localhost
```

**Expected result:** `hello from host` — the file you wrote on the node in Step 1, served
by nginx from the mounted volume. The `NODE` column must show the node from Step 1.

If you get nginx's default welcome page instead, the pod is running on a different node
from the directory — check the node affinity in Step 2.

---

## Step 5 — Persistence test

```bash
kubectl exec web -- sh -c 'echo "from pod" > /usr/share/nginx/html/index.html'
kubectl delete pod web
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: { name: web }
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - { name: data, mountPath: /usr/share/nginx/html }
  volumes:
  - name: data
    persistentVolumeClaim: { claimName: pvc-host }
EOF
kubectl wait --for=condition=Ready pod/web --timeout=60s
kubectl exec web -- curl -s localhost
ssh $TARGET "cat /mnt/data/index.html"
```

**Expected result:** `from pod` from both commands — the new pod sees what the old one
wrote, and the data is really on the node's disk. The pod was deleted and recreated; the
volume was not.

---

## Step 6 — Reclaim behavior

```bash
kubectl delete pod web
kubectl delete pvc pvc-host
kubectl get pv pv-host
```

**Expected result:** the PV is `Released`, **not** `Available` — and a new PVC will *not*
bind to it, even an identical one. With `Retain` the data is deliberately kept and the
volume quarantined for an admin to inspect.

Make it reusable by clearing the stale claim reference:

```bash
kubectl patch pv pv-host --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'
kubectl get pv pv-host
```

**Expected result:** `Available` again. With `persistentVolumeReclaimPolicy: Delete` the PV
(and its data) would have been removed instead — which is the default for dynamically
provisioned volumes in Lab 24.

---

## Step 7 — Cleanup

```bash
kubectl delete pv pv-host
ssh $TARGET "sudo rm -rf /mnt/data"
```

**Expected result:** the PV is gone and the directory is removed **from the worker** — the
node where you created it.

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — host dir | `hello from host` written on the worker node |
| Step 2 — PV | `Available`, `1Gi`, `Retain`, node affinity naming the worker |
| Step 3 — PVC | `Bound` to `pv-host`; PV shows `CLAIM default/pvc-host` |
| Step 4 — mount | `hello from host`, pod running on the expected node |
| Step 5 — persistence | `from pod` from both the pod and the node's filesystem |
| Step 6 — reclaim | PV `Released`, then `Available` after removing `claimRef` |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| nginx serves its default page | The pod is on a node without `/mnt/data`. Add the node affinity from Step 2. |
| PVC stays `Pending` | `kubectl describe pvc pvc-host` — usually a `storageClassName` or size mismatch. |
| PV stays `Released` and nothing binds | Expected with `Retain`. Remove `spec.claimRef` as in Step 6. |
| `ssh: Could not resolve hostname` | Single-node cluster: drop the `ssh $TARGET` wrapper and run the command locally. |
| PV created with an empty node name | `$TARGET` was unset (new shell). Re-run Step 1, then delete and recreate the PV - `nodeAffinity` cannot be patched afterwards. |
| `Permission denied` writing to the mount | nginx runs as root here; a non-root image needs `fsGroup` in the pod's `securityContext`. |
| Pod `Pending` with `volume node affinity conflict` | The PV is pinned to a node that cannot take the pod — check the node name in the affinity. |

---

## What you learned
- PV/PVC binding rules: storage class + size + access mode match.
- The four access modes and three reclaim policies.
- PVCs outlive pods.
