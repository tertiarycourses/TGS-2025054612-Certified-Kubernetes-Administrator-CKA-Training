# Step 6 — Cleanup

```bash
kubectl delete svc web-clusterip web-nodeport web-lb
kubectl delete deploy web
# MetalLB claims node addresses, so remove it before other networking labs:
kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml --ignore-not-found
```

**Expected result:** all three Services and the Deployment are gone, and the
`metallb-system` namespace is removed.
