# Step 2 — Diagnose with `auth can-i`

```bash
kubectl -n app auth can-i list pods --as=system:serviceaccount:app:worker
kubectl -n app auth can-i --list --as=system:serviceaccount:app:worker | head -5
```

**Expected result:** `no`, and the `--list` output shows only the self-review permissions
every identity has.

`--as` impersonates — available because *you* are cluster-admin — and answers "what could
they do?" without a token. It is the fastest RBAC debugging tool there is, and it agrees
with the `403` you just saw from inside the pod.
