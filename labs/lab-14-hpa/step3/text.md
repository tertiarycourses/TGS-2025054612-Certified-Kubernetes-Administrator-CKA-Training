# Step 3 — Create the HPA

```bash
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=5
kubectl get hpa
```

**Expected result:** at first `TARGETS` reads `<unknown>/50%`. That is normal for the first
15-30 seconds, until the HPA controller has a metrics sample. Wait for a real number:

```bash
until kubectl get hpa php-apache -o jsonpath='{.status.currentMetrics}' | grep -q averageUtilization; do
  sleep 10; echo "waiting for the first metric..."
done
kubectl get hpa php-apache
```

**Expected result:** `TARGETS` becomes something like `0%/50%` with `REPLICAS 1`. If it
stays `<unknown>` for minutes, the Deployment has no CPU **request** (Step 2) or
metrics-server is not serving (Step 1).
