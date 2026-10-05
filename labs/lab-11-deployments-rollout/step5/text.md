# Step 5 — Roll back

```bash
kubectl rollout undo deploy/web
kubectl rollout status deploy/web
kubectl rollout history deploy/web
```

**Expected result:** `deployment.apps/web rolled back`, the bad pod disappears, and all
four pods run `nginx:1.26` again. `history` gains another revision — a rollback rolls
*forward* to a new revision with the old spec; it never rewrites history.

Go back to a specific revision:

```bash
kubectl rollout undo deploy/web --to-revision=1
kubectl get deploy web -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

**Expected result:** `nginx:1.25` — revision 1's image.
