# Step 5 — StatefulSet (stable identity)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata: { name: web-headless }
spec:
  clusterIP: None
  selector: { app: web-ss }
  ports: [{ port: 80 }]
---
apiVersion: apps/v1
kind: StatefulSet
metadata: { name: web-ss }
spec:
  serviceName: web-headless
  replicas: 3
  selector: { matchLabels: { app: web-ss } }
  template:
    metadata: { labels: { app: web-ss } }
    spec:
      containers:
      - name: nginx
        image: nginx
        ports: [{ containerPort: 80 }]
EOF
kubectl rollout status statefulset/web-ss
kubectl get pods -l app=web-ss
```

**Expected result:** exactly `web-ss-0`, `web-ss-1`, `web-ss-2` — **ordinal names, created
in order**, unlike a Deployment's random suffixes. Each gets a DNS A record from the
headless Service:

```bash
kubectl run dnstest --image=busybox:1.36 --rm -it --restart=Never -- \
  nslookup web-ss-0.web-headless.default.svc.cluster.local
```

**Expected result:** the lookup returns `web-ss-0`'s pod IP. Delete `web-ss-1` and it comes
back with the *same name* and the same DNS record — that is the stable identity a database
replica needs.

> **This StatefulSet has no storage.** Stable per-pod volumes need
> `volumeClaimTemplates`, which needs a StorageClass this cluster does not have yet —
> that is Labs 23-25. Identity and storage are separate guarantees; this step demonstrates
> identity only.
