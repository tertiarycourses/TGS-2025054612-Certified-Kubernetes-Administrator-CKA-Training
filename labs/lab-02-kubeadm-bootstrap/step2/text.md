# Step 2 — Set up your kubeconfig

Still on **controlplane**:

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes
```

**Expected result:** `kubectl get nodes` lists the control plane as **`NotReady`**.

That is correct, not a failure: there is no pod network yet, so the kubelet reports
`container runtime network not ready`. Lab 3 installs a CNI and the node flips to `Ready`.

> If `kubectl` instead says `The connection to the server localhost:8080 was refused`, the
> kubeconfig copy above did not happen — re-run those three commands.
