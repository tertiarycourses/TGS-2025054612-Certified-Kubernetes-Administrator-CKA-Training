# Step 5 — Mount it in a StatefulSet

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
