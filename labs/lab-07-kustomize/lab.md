# Lab 7 — Customize Manifests with Kustomize

Kustomize is the template-free overlay tool built into `kubectl`. In this lab you build one
base and two overlays — `dev` and `prod` — that change the namespace, replica count and
image tag **without copying or templating any YAML**.

**Lab environment:** [two-node playground](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node) ·
**Prerequisite:** a working cluster (`kubectl get nodes` responds)

---

## What you must be able to show

| Outcome | How you prove it |
|---|---|
| A base renders on its own | `kubectl kustomize kustom/base` shows `replicas: 1`, `nginx:1.25`, no namespace |
| Overlays change only what they declare | dev renders `web-dev`/1/`1.25`, prod renders `web-prod`/4/`1.27` |
| One base, two live environments | the `jsonpath` comparison in Step 4 |
| Render vs apply | `kubectl kustomize` prints YAML; `kubectl apply -k` creates objects |
| Both patch styles | the JSON 6902 patch in Step 2, the strategic-merge patch in Step 5 |

---

## Step 1 — Create the base

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

---

## Step 2 — Create the dev overlay

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

---

## Step 3 — Create the prod overlay

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

---

## Step 4 — Render and apply

`kubectl kustomize` renders; `kubectl apply -k` renders **and** applies. The namespaces an
overlay names must already exist:

```bash
kubectl create ns web-dev
kubectl create ns web-prod
kubectl apply -k kustom/overlays/dev
kubectl apply -k kustom/overlays/prod
```

Now compare the two environments built from one base:

```bash
for ns in web-dev web-prod; do
  echo "== $ns"
  kubectl -n $ns get deploy web \
    -o jsonpath='{.spec.replicas} replicas, image {.spec.template.spec.containers[0].image}{"\n"}'
done
```

**Expected result:**

```text
== web-dev
1 replicas, image nginx:1.25
== web-prod
4 replicas, image nginx:1.27
```

On a 1-CPU node the four prod pods may take a minute; `kubectl -n web-prod get pods -w`
shows progress. The label from the base is on both:

```bash
kubectl -n web-prod get deploy web --show-labels
```

**Expected result:** labels include `app=web`.

---

## Step 5 — Swap the JSON 6902 patch for a strategic-merge patch

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

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — base | Deployment + Service `web`, `replicas: 1`, `nginx:1.25`, no namespace |
| Step 2 — dev render | `namespace: web-dev`, `replicas: 1`, `image: nginx:1.25` |
| Step 3 — prod render | `namespace: web-prod`, `replicas: 4`, `image: nginx:1.27` |
| Step 4 — applied | `web-dev` → `1 replicas, image nginx:1.25`; `web-prod` → `4 replicas, image nginx:1.27` |
| Step 5 — strategic patch | render shows `replicas: 2`; Deployment reports `2/2` |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `must build at directory: not a valid directory` | You pointed `-k` at a file or a path with no `kustomization.yaml`. Pass the **directory**. |
| `accumulating resources … evalsymlink failure` | The `resources:` path is wrong. From `overlays/dev`, the base is `../../base`. |
| `namespaces "web-dev" not found` | An overlay's `namespace:` must exist first: `kubectl create ns web-dev`. |
| `add operation does not apply: doc is missing path` | A JSON 6902 `path` that does not exist in the target. Check it against `kubectl kustomize` output. |
| `field is immutable` on apply | You changed a Deployment's selector. Keep `includeSelectors: false` on `labels:`. |
| Deprecation warnings about `commonLabels` / `patchesStrategicMerge` | Old keys. Use `labels:` and `patches:` as this lab does. |

---

## What you learned
- Base + overlay structure, and that overlays declare **differences** only.
- JSON 6902 (`op`/`path`/`value`) versus strategic-merge (a fragment of the object), and
  that both now live under `patches:`.
- `images:` for retagging without editing the base.
- `kubectl kustomize` (render) versus `kubectl apply -k` (render + apply) — and that
  rendering first is how you check an overlay before it touches the cluster.
