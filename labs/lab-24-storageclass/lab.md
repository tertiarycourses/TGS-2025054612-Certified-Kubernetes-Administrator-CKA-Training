# Lab 24 — StorageClass and Dynamic Provisioning

Static PVs don't scale. With dynamic provisioning, a StorageClass + CSI driver creates a PV on demand when a PVC is submitted. In this lab you install the local-path-provisioner, create a default StorageClass, and watch a PVC trigger PV creation.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Check existing storage classes

```bash
kubectl get storageclass
```

**Expected result:** on a plain `kubeadm` cluster, `No resources found` — there is no
dynamic provisioning until you add a provisioner. If a `local-path` class is already listed
(some playground images ship one), skip Step 2.

---

## Step 2 — Install local-path-provisioner

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.37/deploy/local-path-storage.yaml
kubectl -n local-path-storage rollout status deploy/local-path-provisioner --timeout=180s
kubectl get storageclass
```

**Expected result:** a StorageClass named `local-path` with provisioner
`rancher.io/local-path` and **`VOLUMEBINDINGMODE: WaitForFirstConsumer`** — remember that
column, it decides the behaviour in Step 4.

> Pinned to `v0.0.37` rather than `master`: a moving branch has broken this lab between
> course runs before.

---

## Step 3 — Mark it as default

```bash
kubectl patch storageclass local-path \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl get sc
```

**Expected result:** the class now reads `local-path (default)`.

Only **one** class may be the default. Mark two and PVCs that omit `storageClassName` are
rejected, so clear the old one first when switching.

---

## Step 4 — Create a PVC without specifying a class

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

---

## Step 5 — Mount it in a StatefulSet

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata: { name: db-headless }
spec:
  clusterIP: None
  selector: { app: db }
  ports: [{ port: 5432 }]
---
apiVersion: apps/v1
kind: StatefulSet
metadata: { name: db }
spec:
  serviceName: db-headless
  replicas: 2
  selector: { matchLabels: { app: db } }
  template:
    metadata: { labels: { app: db } }
    spec:
      containers:
      - name: pg
        image: postgres:16-alpine
        env:
        - { name: POSTGRES_PASSWORD, value: changeme }
        volumeMounts:
        - { name: data, mountPath: /var/lib/postgresql/data, subPath: pg }
  volumeClaimTemplates:
  - metadata: { name: data }
    spec:
      accessModes: [ReadWriteOnce]
      resources: { requests: { storage: 500Mi } }
EOF
kubectl rollout status statefulset/db --timeout=300s
kubectl get pvc
kubectl get pv
```

**Expected result:** PVCs `data-db-0` and `data-db-1`, each `Bound` to its own PV, and pods
`db-0`, `db-1` Running.

Each replica gets its **own** volume from the same template — that is how databases scale
in Kubernetes. On a 1-CPU playground two PostgreSQL pods are slow to start, and `db-1` may
stay `Pending` for a while; the PVC naming is the lesson either way.

---

## Step 6 — Verify the volume lifecycle

```bash
kubectl exec db-0 -- psql -U postgres -c "create table t(x int); insert into t values(1);"
kubectl delete pod db-0
kubectl wait --for=condition=Ready pod/db-0 --timeout=120s
kubectl exec db-0 -- psql -U postgres -c "select * from t;"
```

**Expected result:**

```text
 x
---
 1
(1 row)
```

The pod was destroyed and recreated, but `db-0` kept **its** PVC — a StatefulSet pod always
re-attaches to the volume matching its ordinal, which is why it can run a database.

---

## Step 7 — Cleanup

```bash
kubectl delete statefulset db
kubectl delete svc db-headless
kubectl delete pod user --ignore-not-found
kubectl delete pvc -l app=db
kubectl delete pvc data-pvc
kubectl get pvc,pv
```

**Expected result:** no PVCs remain, and the PVs disappear with them — the dynamic class
uses reclaim policy `Delete`, so the volume *and its data* go away. Contrast Lab 23, where
`Retain` kept both.

> **PVCs from `volumeClaimTemplates` are never auto-deleted** when you remove the
> StatefulSet: Kubernetes assumes the data matters more than the controller. Deleting them
> is a deliberate act, which is exactly why this step exists.

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — before | `No resources found` — no StorageClass yet |
| Step 2 — provisioner | `local-path` class with `WaitForFirstConsumer` |
| Step 3 — default | `local-path (default)` |
| Step 4 — binding mode | PVC `Pending` with `waiting for first consumer`, then `Bound` once a pod uses it |
| Step 5 — StatefulSet | `data-db-0` and `data-db-1` each Bound to their own PV |
| Step 6 — persistence | the row survives deleting `db-0` |
| Step 7 — cleanup | PVCs and their PVs both gone (reclaim `Delete`) |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| PVC stays `Pending` with no PV | Expected with `WaitForFirstConsumer` — create a consumer pod (Step 4). |
| PVC `Pending` and no default class | Either set the default annotation or name `storageClassName` explicitly. |
| `db-1` never starts | StatefulSets start pods in order and 1 CPU is tight; `kubectl describe pod db-1`. |
| `psql: could not connect` | PostgreSQL is still initialising: `kubectl logs db-0` and retry. |
| PVs remain after deleting PVCs | The class's reclaim policy is `Retain`; delete the PVs explicitly. |
| Two default StorageClasses | PVCs omitting a class are rejected. Remove the annotation from one. |

---

## What you learned
- StorageClass + provisioner = dynamic PV creation.
- The default-class annotation lets PVCs omit `storageClassName`.
- `volumeClaimTemplates` give each StatefulSet replica its own persistent volume.
