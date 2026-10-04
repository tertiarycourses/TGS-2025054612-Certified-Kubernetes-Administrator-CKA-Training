# Step 3 — Create the state you are going to lose

```bash
kubectl create namespace demo-backup
kubectl -n demo-backup create deployment web --image=nginx:1.27-alpine --replicas=2
kubectl -n demo-backup expose deployment web --port=80
kubectl -n demo-backup create configmap app-config --from-literal=owner=mohan
kubectl -n demo-backup get deploy,svc,cm
```

Pods may stay `Pending` if this cluster has no CNI yet (Lab 3) — the restore is proven by
the objects returning, not by pods running.
