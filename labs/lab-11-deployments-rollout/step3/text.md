# Step 3 — Perform a rolling update

```bash
kubectl set image deploy/web nginx=nginx:1.26
kubectl annotate deploy/web kubernetes.io/change-cause="set image nginx:1.26" --overwrite
kubectl rollout status deploy/web
kubectl rollout history deploy/web
```

**Expected result:** the rollout completes and `history` lists revisions 1 and 2, with
revision 2's `CHANGE-CAUSE` reading `set image nginx:1.26`.

> **Why not `--record`?** That flag is deprecated upstream (`--record will be removed in the
> future`) and prints a warning. The annotation
> `kubernetes.io/change-cause` is what `--record` wrote anyway, and setting it yourself is
> the supported way to fill in `CHANGE-CAUSE`.

Watch in another shell:

```bash
kubectl get pods -l app=web -w
```

You'll see new pods come up while old ones are still serving — that's the surge.
