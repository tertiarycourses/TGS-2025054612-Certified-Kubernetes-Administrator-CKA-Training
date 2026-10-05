# Step 4 — Pod records (headless services)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata: { name: web-h }
spec:
  clusterIP: None
  selector: { app: web }
  ports: [{ port: 80 }]
EOF
kubectl exec dnsdebug -- dig +short web-h.default.svc.cluster.local
kubectl get pods -l app=web -o jsonpath='{.items[*].status.podIP}{"\n"}'
```

**Expected result:** the two outputs match — the headless lookup returns the **pod IPs**
directly, because `clusterIP: None` means there is no virtual IP to hand out. Clients then
load-balance themselves, which is what StatefulSet peers rely on.
