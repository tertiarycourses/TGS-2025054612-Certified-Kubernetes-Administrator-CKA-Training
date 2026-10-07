# Step 4 — Trace a pod through all three interfaces

`crictl` talks to the container runtime on **this** node only. A plain `kubectl run`
schedules onto the worker (the control plane is tainted), and then `crictl ps` here matches
nothing. Pin the pod to the node you are sitting on — `nodeName` bypasses the scheduler, so
the control-plane taint does not apply:

```bash
kubectl run demo --image=nginx --overrides="{\"spec\":{\"nodeName\":\"$(hostname)\"}}"
kubectl wait --for=condition=Ready pod/demo --timeout=120s
kubectl get pod demo -o wide
```

**Expected result:** `demo` is `Running` on this node — check the `NODE` column matches
`hostname`.

```bash
# CRI side - the runtime on this node knows the container
sudo crictl ps | grep demo

# CNI side - the plugin gave it an IP from the pod CIDR
kubectl get pod demo -o jsonpath='{.status.podIP}{"\n"}'
sudo ls /var/log/pods/ | grep default_demo

# CSI side - only exists if a driver is installed
kubectl describe csinode $(hostname) 2>/dev/null || echo "no csinode object (no CSI driver installed)"
```

**Expected result:** `crictl ps` lists the pod's container, the pod has an IP from the CNI's
pod CIDR (`192.168.x.x` after Lab 2), `/var/log/pods/` holds a `default_demo_<uid>`
directory, and the CSI lookup reports no driver — the three interfaces in one pod's
lifecycle, all visible from this node.

> **Everything node-scoped follows the pod.** `crictl`, `/var/log/pods/` and the CNI's
> bookkeeping exist only where the pod runs — which is why Lab 28 has you `ssh` to the
> pod's node to read its log files. `kubectl` works from anywhere because the API server
> proxies to the right kubelet; the node-level tools do not.

Tear down:

```bash
kubectl delete pod demo
```
