# Step 1 — Create from literals

```bash
kubectl create configmap app-config \
  --from-literal=APP_ENV=prod \
  --from-literal=APP_TIER=backend
kubectl get configmap app-config -o yaml
```

**Expected result:** a ConfigMap whose `data:` holds `APP_ENV: prod` and
`APP_TIER: backend` — stored as plain text, not base64. That is the difference from a
Secret, and the reason ConfigMaps must never hold credentials.
