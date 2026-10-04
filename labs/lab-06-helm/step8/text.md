# Step 8 — Diagnose a retired chart repository (Bitnami)

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
