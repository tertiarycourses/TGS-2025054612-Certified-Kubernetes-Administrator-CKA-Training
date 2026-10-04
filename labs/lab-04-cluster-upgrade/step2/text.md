# Step 2 — Point apt at the target minor, then upgrade the kubeadm binary

Target exactly one minor above what Step 1 printed:

```bash
TARGET_MINOR=v1.37          # one minor above what Step 1 printed
LIST=/etc/apt/sources.list.d/kubernetes.list
KEYRING=$(grep -oE '/etc/apt/keyrings/[^] ]+\.gpg' $LIST)
echo "list=$LIST keyring=$KEYRING target=$TARGET_MINOR"

sudo sed -i "s|core:/stable:/v1\.[0-9]*|core:/stable:/${TARGET_MINOR}|" $LIST
curl -fsSL https://pkgs.k8s.io/core:/stable:/${TARGET_MINOR}/deb/Release.key \
  | sudo gpg --yes --dearmor -o "$KEYRING"
sudo apt update
apt-cache madison kubeadm | head -3
```

Read the exact package string from `madison` rather than guessing it, then install:

```bash
PKG=$(apt-cache madison kubeadm | awk '{print $3}' | head -1)
echo "installing kubeadm=$PKG"
sudo apt-mark unhold kubeadm
sudo apt install -y kubeadm=$PKG
sudo apt-mark hold kubeadm
kubeadm version -o short
```

Keep this shell open — `$PKG` is reused in Step 5.
