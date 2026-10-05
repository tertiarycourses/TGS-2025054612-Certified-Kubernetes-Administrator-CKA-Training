# Step 5 — Clean up

```bash
kubectl delete certificate test-cert
kubectl delete issuer selfsigned
kubectl delete widget blue-widget
kubectl delete crd widgets.training.example.com
helm -n cert-manager uninstall cert-manager
kubectl delete ns cert-manager
kubectl get crds | grep cert-manager.io || echo "cert-manager CRDs removed"
```

**Expected result:** the Widget CRD and its instance are gone, and the cert-manager CRDs
are removed too (the chart installed them because of `crds.enabled=true`, so `helm
uninstall` takes them away). **Deleting a CRD deletes every object of that kind** — there is
no undo, which is why operators ship them separately from the workload.
