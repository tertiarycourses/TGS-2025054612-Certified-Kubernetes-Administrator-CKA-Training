# Lab 6 — Install Components with Helm

Helm is the package manager for Kubernetes. In this lab you install the CLI, add a chart
repository, deploy an application, override its values twice, roll back, render templates
without installing, and finish by diagnosing a **retired** chart repository — a failure you
will meet in most older Helm tutorials.

**Lab environment:** [two-node playground](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node) ·
**Prerequisite:** a working cluster (`kubectl get nodes` responds)

> **Why podinfo and not `bitnami/nginx`?** Bitnami retired its public catalog in 2025:
> `helm pull bitnami/nginx` now returns **403**, and older charts point at image tags that
> return **404** from `docker.io/bitnami`. Step 8 walks through exactly that, because
> recognising it is the useful skill. The rest of the lab uses
> [podinfo](https://github.com/stefanprodan/podinfo), a small maintained chart that runs
> comfortably on a 1-CPU node.

---

## What you must be able to show

| Outcome | How you prove it |
|---|---|
| The repo / chart / release model | `helm repo add`, then `helm list` showing release `web` |
| You can discover a chart's knobs | `helm show values podinfo/podinfo` |
| Overrides reach the application | `curl /api/info` returns the `ui.message` you set |
| Upgrades create revisions | `helm history web` lists revisions 1 and 2 |
| Rollback works | revision 3 is a rollback to 1, and `get values` matches revision 1 |
| Render ≠ install | `helm template` prints YAML and changes nothing |
| You can diagnose a dead repo | `helm pull bitnami/nginx` → 403, and the 404 image tag behind `ImagePullBackOff` |

---

## Step 1 — Install the Helm CLI

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

**Expected result:** `version.BuildInfo{Version:"v3…"}`. Helm 3 talks to the API server
with your kubeconfig — there is no in-cluster component to install.

---

## Step 2 — Add a chart repository

```bash
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update
helm search repo podinfo
```

**Expected result:** `podinfo/podinfo` with a chart version and app version.

`helm repo add` stores the repo's `index.yaml` locally, `helm repo update` refreshes it, and
`helm search repo` queries **that local copy** — not the network. A stale index is why a
chart version you know exists sometimes cannot be found.

Before installing anything, read what the chart exposes:

```bash
helm show chart podinfo/podinfo | head -12
helm show values podinfo/podinfo | head -25
```

**Expected result:** the chart metadata, then its default values — `replicaCount`,
`image`, `service`, `ui` among them. `helm show values` is the only reliable way to know
what you are allowed to override; never guess a key.

---

## Step 3 — Install a chart

```bash
helm install web podinfo/podinfo \
  --namespace web --create-namespace \
  --set replicaCount=2 \
  --set ui.message="hello from revision 1"
```

`web` is the **release name** — this installation's identity in the cluster. The same chart
can be installed many times under different release names.

```bash
helm -n web list
kubectl -n web get deploy,pod,svc
kubectl -n web rollout status deploy/web-podinfo --timeout=120s
```

**Expected result:** `helm list` shows release `web`, `REVISION 1`, status `deployed`; the
Deployment reports `2/2` ready. On a 1-CPU node the pods may take a minute.

See the value you set actually reach the application:

```bash
kubectl -n web port-forward svc/web-podinfo 9898:9898 > /dev/null 2>&1 &
sleep 3
curl -s http://localhost:9898/api/info | head -c 200; echo
kill %1
```

**Expected result:** JSON containing `"message": "hello from revision 1"`.

---

## Step 4 — Override values with a file

`--set` is fine for one or two keys; real deployments keep a values file under version
control. Create one:

```bash
cat > values.yaml <<'EOF'
replicaCount: 3
ui:
  message: "hello from revision 2"
service:
  type: ClusterIP
EOF
helm upgrade web podinfo/podinfo -n web -f values.yaml
```

```bash
kubectl -n web get deploy web-podinfo
helm -n web history web
```

**Expected result:** the Deployment scales to `3/3`, and `history` lists **two** revisions —
revision 1 `superseded`, revision 2 `deployed`.

> **`--set` and `-f` do not merge across commands.** Each `helm upgrade` computes the
> release from the chart defaults plus *only* the overrides given in that command. The
> `--set ui.message` from Step 3 is gone unless the values file repeats it — which is why
> revision 2 must set the message again. Use `helm get values web -n web` to see exactly
> what a release is currently using.

---

## Step 5 — Roll back

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

---

## Step 6 — Render without installing

```bash
helm template web podinfo/podinfo -f values.yaml | head -40
```

**Expected result:** plain Kubernetes YAML on stdout and **nothing** created in the cluster.
`helm template` is the GitOps-friendly path: render, commit, let a controller apply it.

Useful relatives:

```bash
helm upgrade web podinfo/podinfo -n web -f values.yaml --dry-run | head -20
helm -n web get manifest web | head -20
```

`--dry-run` asks the API server to validate without persisting; `get manifest` prints what
the release actually applied.

---

## Step 7 — Uninstall

```bash
helm -n web uninstall web
kubectl -n web get all
kubectl delete ns web
```

**Expected result:** `release "web" uninstalled`, then `No resources found` — uninstall
removes everything the release created, but **not** the namespace, which `helm` only made
because you passed `--create-namespace`.

---

## Step 8 — Diagnose a retired chart repository (Bitnami)

Most Helm material still says `helm repo add bitnami https://charts.bitnami.com/bitnami`.
Bitnami retired that public catalog in 2025, and the failures are worth recognising because
you will hit them in old guides:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo bitnami/nginx | head -3
helm pull bitnami/nginx
```

**Expected result:** `search` *finds* the chart — the index is still published — but `pull`
fails with a **403 Forbidden**. The index lists charts that are no longer downloadable.

An older pinned chart still downloads, yet its image does not exist any more:

```bash
helm pull bitnami/nginx --version 21.0.0 --untar
grep -A3 "^image:" nginx/values.yaml
```

**Expected result:** `repository: bitnami/nginx`, `tag: 1.29.0-debian-12-r0`. That tag was
moved to the frozen `bitnamilegacy` repository, so installing this chart leaves pods in
`ImagePullBackOff`:

That tag returns **404** from `docker.io/bitnami` and **200** from
`docker.io/bitnamilegacy` — the images were moved, not deleted.

**The lesson, which is examinable:** when pods fail to start after a `helm install`, the
chart is rarely at fault — read the image it chose and verify that it exists:

```bash
kubectl -n <ns> describe pod <pod> | grep -A3 Events
helm -n <ns> get manifest <release> | grep image:
```

Then override the registry if a legacy mirror exists
(`--set image.repository=bitnamilegacy/nginx`), or pick a maintained chart. Clean up:

```bash
helm repo remove bitnami
rm -rf nginx nginx-21.0.0.tgz
```

---

## Verification

| Check | Expected |
|---|---|
| Step 1 | `helm version` prints `v3.x` |
| Step 2 | `helm search repo podinfo` lists `podinfo/podinfo`; `helm show values` lists `replicaCount`, `ui`, `service` |
| Step 3 | release `web` at revision 1, Deployment `2/2`, `/api/info` shows `hello from revision 1` |
| Step 4 | Deployment `3/3`, two revisions in `helm history` |
| Step 5 | revision 3 = rollback to 1, Deployment back to `2/2`, one Secret per revision |
| Step 6 | YAML on stdout, nothing created |
| Step 7 | `release "web" uninstalled`, then `No resources found` |
| Step 8 | `helm pull bitnami/nginx` → 403; chart 21.0.0's image tag → 404 from `docker.io/bitnami` |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `Error: INSTALLATION FAILED: … 403 Forbidden` | The chart repo no longer serves downloads (Bitnami). Use a maintained chart — see Step 8. |
| Pods stuck `ImagePullBackOff` after install | The chart's image tag does not exist. `helm get manifest <release> \| grep image:`, then verify the tag, and override `image.repository`/`image.tag`. |
| `Error: … chart not found` right after `repo add` | Stale local index: `helm repo update`. |
| An override "disappeared" after an upgrade | `--set`/`-f` are not cumulative. Repeat every override, or keep them all in the values file. `helm get values <release>` shows the truth. |
| `cannot re-use a name that is still in use` | A release with that name exists: `helm list -A`, then `helm uninstall` or pick another name. |
| `port-forward` fails or hangs | The pod is not Ready yet: `kubectl -n web rollout status deploy/web-podinfo`. |

---

## What you learned
- The repo / chart / release model, and that Helm 3 keeps release state in Secrets.
- `helm show values` before `--set`, and that overrides are **not** cumulative between
  upgrades.
- Revisions, `history`, and instant `rollback`.
- `helm template` for GitOps, `--dry-run` for validation, `get manifest` for what shipped.
- How to recognise a retired chart repository (403) and a vanished image tag (404) instead
  of blaming the cluster.
