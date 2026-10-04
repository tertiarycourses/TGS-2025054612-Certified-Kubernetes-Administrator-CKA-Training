# Step 5 — Swap the JSON 6902 patch for a strategic-merge patch

A strategic-merge patch is a **fragment of the real object**: easier to read, and it merges
lists by key instead of by index. Rewrite the dev overlay to use one, and set replicas to 2
so you can see it take effect.

Create the patch file:

```bash
cat > kustom/overlays/dev/replica-patch.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2
EOF
```

Replace the dev `kustomization.yaml` completely — this is the whole file, patch swapped:

```bash
cat > kustom/overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: web-dev
resources:
  - ../../base
patches:
  - path: replica-patch.yaml
images:
  - name: nginx
    newTag: "1.25"
EOF
```

Apply and watch the rollout:

```bash
kubectl kustomize kustom/overlays/dev | grep -E "replicas:|image:"
kubectl apply -k kustom/overlays/dev
kubectl -n web-dev rollout status deploy/web --timeout=120s
kubectl -n web-dev get deploy web
```

**Expected result:** the render shows `replicas: 2`, and the Deployment reports `2/2`.

> Both patch styles live under the same `patches:` key — `path:` for a file, `patch:` for an
> inline one, with `target:` when the file does not already identify the object. The older
> `patchesStrategicMerge:` and `patchesJson6902:` keys still work but are deprecated.

Clean up when you are done:

```bash
kubectl delete -k kustom/overlays/dev
kubectl delete -k kustom/overlays/prod
kubectl delete ns web-dev web-prod
```
