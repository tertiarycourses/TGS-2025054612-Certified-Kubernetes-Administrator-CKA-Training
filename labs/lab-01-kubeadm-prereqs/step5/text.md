# Step 5 — Install kubeadm, kubelet, kubectl

```bash
sudo apt install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

**Expected result:** the three packages install and `apt-mark` reports
`kubelet set on hold`, `kubeadm set on hold`, `kubectl set on hold`.

`apt-mark hold` pins the versions so a stray `apt upgrade` cannot break your cluster
mid-term — and it is why Lab 4's upgrade starts with `apt-mark unhold`.
