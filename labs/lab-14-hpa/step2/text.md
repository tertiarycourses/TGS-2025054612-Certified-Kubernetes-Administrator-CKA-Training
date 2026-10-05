# Step 2 — Deploy a CPU-bound workload

```bash
kubectl create deployment php-apache --image=registry.k8s.io/hpa-example
kubectl set resources deploy/php-apache --requests=cpu=100m --limits=cpu=500m
kubectl expose deployment php-apache --port=80
kubectl rollout status deploy/php-apache
```

**Expected result:** `successfully rolled out`, one pod Running.

The `--requests=cpu=100m` is **mandatory**, not decoration: HPA computes utilisation as
*usage ÷ request*. With no request there is nothing to divide by, and the HPA reports
`<unknown>` forever.
