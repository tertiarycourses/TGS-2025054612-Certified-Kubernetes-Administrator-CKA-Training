# Step 6 — Render without installing

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
