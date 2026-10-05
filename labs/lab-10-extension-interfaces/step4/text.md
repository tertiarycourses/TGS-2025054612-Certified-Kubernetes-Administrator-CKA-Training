# Step 4 — Trace a pod through all three interfaces

```bash
kubectl run demo --image=nginx
kubectl wait --for=condition=Ready pod/demo --timeout=60s

# CRI side
sudo crictl ps | grep demo

# CNI side
kubectl get pod demo -o jsonpath='{.status.podIP}{"\n"}'

# CSI side - only exists if a driver is installed
kubectl describe csinode $(hostname) 2>/dev/null || echo "no csinode object (no CSI driver installed)"
```

**Expected result:** `crictl ps` shows the pod's container, the pod has an IP from the CNI's
pod CIDR, and the CSI lookup reports no driver — the three interfaces, in one pod's
lifecycle.

Tear down:

```bash
kubectl delete pod demo
```
