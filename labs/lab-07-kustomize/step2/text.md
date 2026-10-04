# Step 2 — Create the dev overlay

An overlay points at the base and states only its differences. Dev keeps one replica but
pins an older image tag:

```bash
mkdir -p kustom/overlays/dev
cat > kustom/overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: web-dev
resources:
  - ../../base
patches:
  - target:
      kind: Deployment
      name: web
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
images:
  - name: nginx
    newTag: "1.25"
EOF
kubectl kustomize kustom/overlays/dev | grep -E "namespace:|replicas:|image:"
```

**Expected result:** `namespace: web-dev`, `replicas: 1`, `image: nginx:1.25`.

That inline patch is **JSON 6902**: a list of `op`/`path`/`value` operations against a
target you name. It is precise and fails loudly if the path does not exist.
