# Step 1 — Create the base

The base holds the manifests every environment shares. Nothing in it is
environment-specific — no namespace, no replica count you care about.

```bash
mkdir -p kustom/base
cat > kustom/base/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: nginx:1.25
        ports:
        - containerPort: 80
EOF
cat > kustom/base/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
EOF
cat > kustom/base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
labels:
  - pairs:
      app: web
    includeSelectors: false
EOF
```

Check the base renders on its own:

```bash
kubectl kustomize kustom/base | grep -E "^kind:|  name:|replicas:|image:"
```

**Expected result:** a Deployment and a Service named `web`, `replicas: 1`, `image:
nginx:1.25`, and no namespace.

> `apiVersion`/`kind` are optional but worth writing — without them newer kustomize prints
> a deprecation warning. `labels:` with `includeSelectors: false` is the modern form of
> `commonLabels`, which still works but is deprecated: it adds the label without touching
> the selector, so it stays safe to change later (selectors are immutable once applied).
