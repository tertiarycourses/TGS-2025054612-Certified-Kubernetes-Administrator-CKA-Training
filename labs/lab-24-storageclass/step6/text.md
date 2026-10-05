# Step 6 — Verify the volume lifecycle

```bash
kubectl exec db-0 -- psql -U postgres -c "create table t(x int); insert into t values(1);"
kubectl delete pod db-0
kubectl wait --for=condition=Ready pod/db-0 --timeout=120s
kubectl exec db-0 -- psql -U postgres -c "select * from t;"
```

**Expected result:**

```text
 x
---
 1
(1 row)
```

The pod was destroyed and recreated, but `db-0` kept **its** PVC — a StatefulSet pod always
re-attaches to the volume matching its ordinal, which is why it can run a database.
