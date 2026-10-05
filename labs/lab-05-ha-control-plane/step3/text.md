# Step 3 — Create the state you are going to lose

A backup proves nothing unless something recognisable disappears and comes back.

```bash
kubectl create namespace demo-backup
kubectl -n demo-backup create deployment web --image=nginx:1.27-alpine --replicas=2
kubectl -n demo-backup expose deployment web --port=80
kubectl -n demo-backup create configmap app-config --from-literal=owner=mohan
kubectl -n demo-backup get deploy,svc,cm
```

**Expected result:** Deployment `web`, Service `web` and ConfigMap `app-config` all listed.

> Pods may sit `Pending` if this cluster has no CNI yet (see Lab 3) — that is fine. The
> restore is proven by the **objects** returning, not by pods running.
