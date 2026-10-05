# Step 2 — Point apt at the target minor, then upgrade the kubeadm binary

Set the target to **exactly one minor above** what Step 1 printed — kubeadm supports one
minor step at a time (v1.36 to v1.37, never v1.35 straight to v1.37). The example below
uses `v1.37`: that is the newest published minor, the one the shared playground already
runs, and the target for this lab's KillerCoda scenario, which provisions a **v1.36**
cluster for you:

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

> **Why `$KEYRING` instead of a fixed filename?** The list line names its own keyring in
> `signed-by=`, and the name includes the minor — on this playground it is
> `/etc/apt/keyrings/kubernetes-1-37-apt-keyring.gpg`. Writing the key to any other file
> leaves the repo unverifiable and `apt update` fails, so read the path out of the list
> file rather than assuming it.

`apt-cache madison` lists the exact package strings that minor publishes, newest first —
for example `1.35.1-1.1`. Never guess this value; read it. Capture it, then install:

```bash
PKG=$(apt-cache madison kubeadm | awk '{print $3}' | head -1)
echo "installing kubeadm=$PKG"
sudo apt-mark unhold kubeadm
sudo apt install -y kubeadm=$PKG
sudo apt-mark hold kubeadm
kubeadm version -o short
```

`kubeadm version -o short` must now show the new version. `$PKG` is used again in Step 5,
so keep this shell open — a new tab or `ssh` session starts without it.
