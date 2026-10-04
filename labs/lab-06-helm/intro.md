# Lab 6 — Install Components with Helm

Helm is the package manager for Kubernetes. You will install the CLI, add a chart
repository, deploy an application, override its values, roll back, render templates without
installing — and finish by diagnosing a **retired** chart repository.

> **Why podinfo and not `bitnami/nginx`?** Bitnami retired its public catalog in 2025:
> `helm pull bitnami/nginx` returns **403**, and older charts reference image tags that
> return **404**. Step 8 reproduces that on purpose; the rest of the lab uses the small,
> maintained podinfo chart.

**Prerequisite:** a working cluster (`kubectl get nodes`).

**What you will do:**
- Install Helm 3 and add the podinfo repository
- Read a chart's values before overriding them
- Install a release, then prove your override reached the app with `curl /api/info`
- Upgrade with a values file, inspect revisions, and roll back
- Render with `helm template` without touching the cluster
- Diagnose the Bitnami 403 and the 404 image tag behind `ImagePullBackOff`
