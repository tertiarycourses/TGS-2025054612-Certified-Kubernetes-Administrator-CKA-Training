# Lab 12 — ConfigMaps

ConfigMaps hold non-secret key/value configuration. In this lab you create a ConfigMap three ways (literal, file, manifest) and consume it in a pod as environment variables and as a mounted file.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Create from literals

```bash
kubectl create configmap app-config \
  --from-literal=APP_ENV=prod \
  --from-literal=APP_TIER=backend
kubectl get configmap app-config -o yaml
```

**Expected result:** a ConfigMap whose `data:` holds `APP_ENV: prod` and
`APP_TIER: backend` — stored as plain text, not base64. That is the difference from a
Secret, and the reason ConfigMaps must never hold credentials.

---

## Step 2 — Create from a file

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

---

## Step 3 — Consume as environment variables

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: env-demo }
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh","-c","env | grep APP_; sleep 3600"]
    envFrom:
    - configMapRef: { name: app-config }
EOF
kubectl wait --for=condition=Ready pod/env-demo --timeout=60s
kubectl logs env-demo
```

**Expected result:**

```text
APP_ENV=prod
APP_TIER=backend
```

`envFrom` imported every key at once. Use `env:` with `configMapKeyRef` when you need one
key, or a different variable name.

---

## Step 4 — Consume as a mounted file

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: file-demo }
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh","-c","cat /etc/cfg/app.properties; sleep 3600"]
    volumeMounts:
    - { name: cfg, mountPath: /etc/cfg }
  volumes:
  - name: cfg
    configMap: { name: app-properties }
EOF
kubectl wait --for=condition=Ready pod/file-demo --timeout=60s
kubectl logs file-demo
```

**Expected result:**

```text
log.level=INFO
cache.ttl=300
```

The ConfigMap key became a **file** at `/etc/cfg/app.properties`. Check what the mount
really looks like:

```bash
kubectl exec file-demo -- ls -l /etc/cfg/
```

**Expected result:** `app.properties` is a symlink into a `..data/` directory — that
indirection is how the kubelet swaps content atomically when the ConfigMap changes.

---

## Step 5 — Update propagation

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

---

## Step 6 — Cleanup

```bash
kubectl delete pod env-demo file-demo
kubectl delete configmap app-config app-properties
```

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — from literals | `data:` shows `APP_ENV: prod` and `APP_TIER: backend` in plain text |
| Step 2 — from a file | a single key `app.properties` holding the file's contents |
| Step 3 — as env vars | pod logs print `APP_ENV=prod` and `APP_TIER=backend` |
| Step 4 — as a mounted file | logs print the properties; the mount is a symlink into `..data/` |
| Step 5 — update propagation | the mounted file becomes `DEBUG` within ~1 minute; env vars keep the old values |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `kubectl edit` opens an editor you cannot paste into | Use the `create … --dry-run=client -o yaml \| kubectl apply -f -` form in Step 5. |
| Mounted file never updates | It was mounted with `subPath`, which pins the content. Mount the directory instead. |
| Env vars did not change | Correct — env is a snapshot. Replace the pod, or `kubectl rollout restart deploy/<name>`. |
| Pod `CreateContainerConfigError` | The ConfigMap or key does not exist: `kubectl describe pod <name>` names the missing key. |
| `invalid configmap key` on `--from-file` | Filenames must be valid keys (alphanumerics, `-`, `_`, `.`). Use `--from-file=key=path` to rename. |
| Update seems slow | Up to ~1 minute is normal: the kubelet refreshes on its sync loop, not on write. |

---

## What you learned
- Three ways to build ConfigMaps.
- Env vs volume-mount consumption and their update semantics.
- Why `rollout restart` is needed for env-based reloads.
