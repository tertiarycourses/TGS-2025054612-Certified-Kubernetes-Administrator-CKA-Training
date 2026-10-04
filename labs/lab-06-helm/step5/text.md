# Step 5 — Roll back

```bash
helm -n web rollback web 1
helm -n web history web
helm -n web get values web
kubectl -n web get deploy web-podinfo
```

**Expected result:** a new revision 3 described as a rollback to 1, the values back to
`replicaCount: 2` and `hello from revision 1`, and the Deployment at `2/2`.

Helm stores the full manifest of every revision in a Secret in the release namespace, which
is what makes rollback instant and offline:

```bash
kubectl -n web get secret -l owner=helm
```

**Expected result:** one `sh.helm.release.v1.web.v*` Secret per revision.
