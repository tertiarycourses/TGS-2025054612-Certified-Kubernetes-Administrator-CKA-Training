# Step 1 — Create a generic Secret

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
