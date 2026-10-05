# Step 5 — Update propagation

Update it without an editor — scriptable, and safe to paste:

```bash
kubectl create configmap app-properties \
  --from-literal=app.properties='log.level=DEBUG
cache.ttl=60' \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl get configmap app-properties -o jsonpath='{.data.app\.properties}{"\n"}'
```

**Expected result:** the stored value now reads `log.level=DEBUG` and `cache.ttl=60`.

Now watch the **mounted file** catch up without restarting anything:

```bash
for i in $(seq 1 15); do
  echo "attempt $i:"; kubectl exec file-demo -- cat /etc/cfg/app.properties
  kubectl exec file-demo -- grep -q DEBUG /etc/cfg/app.properties && { echo "mount updated"; break; }
  sleep 10
done
```

**Expected result:** within about a minute the file shows `log.level=DEBUG` and
`mount updated`.

Environment variables behave differently — they are injected once, at container start:

```bash
kubectl exec env-demo -- env | grep APP_
```

**Expected result:** still the **old** values. `envFrom` and `env` are snapshots; only
mounted volumes refresh. To pick up env changes you must replace the pod — for a Deployment
that is `kubectl rollout restart deploy/<name>`.

> The kubelet refreshes mounted ConfigMaps on its sync loop (about once a minute by
> default, `configMapAndSecretChangeDetectionStrategy`). A ConfigMap mounted with `subPath`
> is the exception: it never updates.
