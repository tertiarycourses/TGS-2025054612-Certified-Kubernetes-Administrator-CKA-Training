# Step 2 — Create from a file

```bash
cat > app.properties <<'EOF'
log.level=INFO
cache.ttl=300
EOF
kubectl create configmap app-properties --from-file=app.properties
kubectl describe configmap app-properties
```

**Expected result:** one key named after the file — `app.properties` — whose value is the
whole file content. `--from-file` keys on the **filename**; `--from-env-file` would instead
read the same file as individual key/value pairs.
