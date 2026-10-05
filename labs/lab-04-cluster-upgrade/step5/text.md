# Step 5 — Upgrade kubelet and kubectl on the control plane

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt install -y kubelet=$PKG kubectl=$PKG
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
kubectl uncordon controlplane
```

**Expected result:** the packages install, the kubelet restarts, and
`node/controlplane uncordoned`. Confirm the node now reports the new version:

```bash
kubectl get nodes
```

**Expected result:** the control plane's `VERSION` column shows the version you upgraded
to — the first visible proof the upgrade worked.

Lost `$PKG` (new shell)? Re-read it with
`PKG=$(apt-cache madison kubeadm | awk '{print $3}' | head -1)`.
