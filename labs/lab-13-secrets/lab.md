# Lab 13 — Secrets

Kubernetes Secrets carry sensitive data — passwords, tokens, TLS keys — and are base64-encoded (not encrypted) by default. In this lab you create a generic Secret, a TLS Secret, and a docker-registry Secret, and use them from pods.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Create a generic Secret

```bash
kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password='S3cure!Pw'
kubectl get secret db-creds -o yaml
```

Notice the base64 values — decode one:

```bash
kubectl get secret db-creds -o jsonpath='{.data.password}' | base64 -d ; echo
```

**Expected result:** `S3cure!Pw`.

That is the whole point of the lab: **anyone who can read the Secret can read the
password.** `base64` is encoding, not encryption. Confirm the type while you are here:

```bash
kubectl get secret db-creds -o jsonpath='{.type}{"\n"}'
```

**Expected result:** `Opaque` — the default type for arbitrary key/value data.

---

## Step 2 — Consume as env vars

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: sec-env }
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh","-c","echo user=$DB_USER pw=$DB_PASS; sleep 3600"]
    env:
    - name: DB_USER
      valueFrom: { secretKeyRef: { name: db-creds, key: username } }
    - name: DB_PASS
      valueFrom: { secretKeyRef: { name: db-creds, key: password } }
EOF
kubectl wait --for=condition=Ready pod/sec-env --timeout=60s
kubectl logs sec-env
```

**Expected result:** `user=admin pw=S3cure!Pw`.

Note what that implies: the value is now in the container's environment, visible to
`kubectl describe pod`-level tooling, crash dumps and child processes. Mounted files
(Step 3) are the safer option.

---

## Step 3 — Consume as a mounted file

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: sec-file }
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh","-c","ls /etc/db; cat /etc/db/username; echo; sleep 3600"]
    volumeMounts:
    - { name: creds, mountPath: /etc/db, readOnly: true }
  volumes:
  - name: creds
    secret: { secretName: db-creds, defaultMode: 0400 }
EOF
kubectl wait --for=condition=Ready pod/sec-file --timeout=60s
kubectl logs sec-file
```

**Expected result:** the listing shows `password` and `username`, then `admin` — one file
per key, named after the key.

Prove the claim that it is memory-backed:

```bash
kubectl exec sec-file -- df -h /etc/db | tail -1
kubectl exec sec-file -- ls -l /etc/db/
```

**Expected result:** the filesystem is `tmpfs`, and the files are symlinks into `..data/`
(the same atomic-swap trick as ConfigMaps). Files mounted from a Secret live in RAM and are
never written to the node's disk.

---

## Step 4 — TLS Secret

```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
  -keyout tls.key -out tls.crt -subj "/CN=demo.local"
kubectl create secret tls demo-tls --cert=tls.crt --key=tls.key
kubectl get secret demo-tls -o jsonpath='{.type}{"\n"}'
kubectl get secret demo-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject
```

**Expected result:** type `kubernetes.io/tls`, and the certificate's subject is
`CN = demo.local`. A `tls` Secret must contain exactly the keys `tls.crt` and `tls.key` —
Ingress and Gateway API controllers look for those names.

TLS Secrets are used by Ingress, Gateway API, and webhook servers (Lab 19, 20).

---

## Step 5 — Docker-registry Secret (private image pull)

```bash
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=demo \
  --docker-password=demo123 \
  --docker-email=demo@example.com
kubectl get secret regcred -o jsonpath='{.type}{"\n"}'
kubectl get secret regcred -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d; echo
```

**Expected result:** type `kubernetes.io/dockerconfigjson`, and the decoded value is a JSON
document containing the server, username and a base64 `auth` field. These credentials are
fake, so no pull will succeed with them — the point is the shape of the object.

Reference from a pod:

```yaml
spec:
  imagePullSecrets:
  - name: regcred
```

---

## Step 6 — Cleanup

```bash
kubectl delete pod sec-env sec-file
kubectl delete secret db-creds demo-tls regcred
rm tls.key tls.crt
```

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — generic Secret | decodes to `S3cure!Pw`; type `Opaque` |
| Step 2 — env vars | `user=admin pw=S3cure!Pw` |
| Step 3 — mounted files | one file per key; `df` reports `tmpfs` |
| Step 4 — TLS Secret | type `kubernetes.io/tls`, subject `CN = demo.local` |
| Step 5 — registry Secret | type `kubernetes.io/dockerconfigjson` with a JSON auth document |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `base64: invalid input` | You decoded the whole object instead of one field. Use `-o jsonpath='{.data.<key>}'` first. |
| A key with a dot fails in jsonpath | Escape it: `{.data.tls\.crt}`. |
| Pod `CreateContainerConfigError` | A missing Secret or key — `kubectl describe pod` names it. |
| `kubectl create secret tls` rejects the files | The cert and key must be PEM and must match. Regenerate with the `openssl` command in Step 4. |
| Secret values visible in `describe` | Expected. Secrets are only base64-encoded; enable `EncryptionConfiguration` on the API server for encryption at rest. |
| `ImagePullBackOff` with `imagePullSecrets` | The credentials here are deliberately fake. Real pulls need real ones in the pod's namespace. |

---

## What you learned
- Generic, TLS, and docker-registry Secret types.
- Env-var vs tmpfs-mount consumption.
- Secrets are base64-encoded, not encrypted — enable EncryptionConfiguration at the API server for at-rest encryption.
