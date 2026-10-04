# Step 3 — Create the prod overlay

Same base, different numbers — this is the whole point of overlays:

```bash
mkdir -p kustom/overlays/prod
cat > kustom/overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: web-prod
resources:
  - ../../base
patches:
  - target:
      kind: Deployment
      name: web
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 4
images:
  - name: nginx
    newTag: "1.27"
EOF
kubectl kustomize kustom/overlays/prod | grep -E "namespace:|replicas:|image:"
```

**Expected result:** `namespace: web-prod`, `replicas: 4`, `image: nginx:1.27` — the base
file was never edited, and never copied.
