# Step 3 — Mark it as default

```bash
kubectl patch storageclass local-path \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl get sc
```

**Expected result:** the class now reads `local-path (default)`.

Only **one** class may be the default. Mark two and PVCs that omit `storageClassName` are
rejected, so clear the old one first when switching.
