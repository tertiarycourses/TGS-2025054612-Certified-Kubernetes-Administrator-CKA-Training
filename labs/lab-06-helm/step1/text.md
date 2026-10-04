# Step 1 — Install the Helm CLI

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

**Expected result:** `version.BuildInfo{Version:"v3…"}`. Helm 3 talks to the API server
with your kubeconfig — there is no in-cluster component to install.
