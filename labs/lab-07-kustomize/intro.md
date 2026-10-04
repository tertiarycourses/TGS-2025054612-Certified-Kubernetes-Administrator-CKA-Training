# Lab 7 — Customize Manifests with Kustomize

Kustomize is the template-free overlay tool built into `kubectl`. You will build one base
and two overlays — `dev` and `prod` — that change namespace, replica count and image tag
without copying or templating any YAML.

**Prerequisite:** a working cluster (`kubectl get nodes`).

**What you will do:**
- Write a base that renders on its own
- Add a dev overlay with a JSON 6902 patch, and a prod overlay with different numbers
- Render with `kubectl kustomize`, then apply with `kubectl apply -k`
- Compare both live environments with one `jsonpath` query
- Swap the JSON 6902 patch for a strategic-merge patch and watch the rollout
