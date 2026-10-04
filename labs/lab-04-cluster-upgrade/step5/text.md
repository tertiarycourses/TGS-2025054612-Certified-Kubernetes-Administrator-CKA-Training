# Step 5 — Upgrade kubelet and kubectl on the control plane

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt install -y kubelet=$PKG kubectl=$PKG
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
kubectl uncordon controlplane
```

New shell, so `$PKG` is empty? Re-read it:
`PKG=$(apt-cache madison kubeadm | awk '{print $3}' | head -1)`
