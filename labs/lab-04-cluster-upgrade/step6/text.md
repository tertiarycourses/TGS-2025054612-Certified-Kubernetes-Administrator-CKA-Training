# Step 6 — Repeat on the worker

node01 has its own apt config, so repoint its repo too. On **node01**:

```bash
TARGET_MINOR=v1.35
sudo sed -i "s|core:/stable:/v1\.[0-9]*|core:/stable:/${TARGET_MINOR}|" \
  /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/${TARGET_MINOR}/deb/Release.key \
  | sudo gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo apt update
PKG=$(apt-cache madison kubeadm | awk '{print $3}' | head -1)
sudo apt-mark unhold kubeadm && sudo apt install -y kubeadm=$PKG && sudo apt-mark hold kubeadm
sudo kubeadm upgrade node
```

Back on **controlplane**:

```bash
kubectl drain node01 --ignore-daemonsets --delete-emptydir-data
```

On **node01**:

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt install -y kubelet=$PKG kubectl=$PKG
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet
```

On **controlplane**:

```bash
kubectl uncordon node01
kubectl get nodes
```

Both nodes should report the new version.
