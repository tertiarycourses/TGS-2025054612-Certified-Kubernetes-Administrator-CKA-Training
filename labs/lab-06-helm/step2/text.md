# Step 2 — Add a chart repository

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
