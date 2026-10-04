# Step 6 — Repeat on the worker

> **This scenario runs a single node**, so there is no `node01` and the upgrade is already
> complete — verify with `kubectl get nodes` and finish. The steps below are for a
> two-node environment such as the KillerCoda two-node playground.

node01 has its own apt config, so repoint its repo too. On **node01**:

```bash
TARGET_MINOR=v1.37          # one minor above what Step 1 printed
LIST=/etc/apt/sources.list.d/kubernetes.list
KEYRING=$(grep -oE '/etc/apt/keyrings/[^] ]+\.gpg' $LIST)
echo "list=$LIST keyring=$KEYRING target=$TARGET_MINOR"

sudo sed -i "s|core:/stable:/v1\.[0-9]*|core:/stable:/${TARGET_MINOR}|" $LIST
curl -fsSL https://pkgs.k8s.io/core:/stable:/${TARGET_MINOR}/deb/Release.key \
  | sudo gpg --yes --dearmor -o "$KEYRING"
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
