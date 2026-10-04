# Lab 1 — kubeadm Prerequisites and Container Runtime

**Folder:** `labs/lab-01-kubeadm-prereqs/`  ·  **Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)

> **Two-node setup:** Open **two browser tabs** of the KillerCoda scenario — Tab 1 is your **controlplane**, Tab 2 is your **node01**. Run every step on **both tabs** unless stated otherwise.

---

## Step 0 — Check what the playground already gives you

The KillerCoda playground is **not** a bare Ubuntu box: it boots with containerd,
`kubeadm`, `kubelet` and `kubectl` already installed **and a cluster already running**.
Find out what you have before you change anything — on **both tabs**:

```bash
kubeadm version -o short || echo "kubeadm NOT installed"
nproc
kubectl get nodes 2>/dev/null || echo "no cluster reachable from this node"
```

Then pick your path:

| What you see | What to do |
|---|---|
| A version (e.g. `v1.37.1`) **and** `kubectl get nodes` lists nodes | The prerequisites are already in place. **Read** Steps 1–5 to learn what each one does, run **Step 6** to verify, then go to Lab 2, which resets the cluster so you bootstrap it yourself. |
| `kubeadm NOT installed` (a bare Ubuntu node) | Run Steps 1–5, then Step 6. |

Write down the version `kubeadm version` printed and the `nproc` count — you need the
version in Lab 4 (upgrade) and the CPU count in Lab 2.

> **Version note:** Step 5 below pins the **v1.35** package repo, but the playground
> currently ships a newer Kubernetes (**v1.37.x**). That is expected. Never mix: if a
> cluster is already running, do not install different `kubeadm`/`kubelet` versions over
> it, or `kubeadm init` and the kubelet will disagree about the version to use.

---

## Goal

Prepare two clean Ubuntu nodes for a Kubernetes cluster install: load the required kernel modules, apply the right sysctls, install `containerd` as the Container Runtime Interface (CRI), and install the `kubeadm`, `kubelet`, and `kubectl` binaries from the official Kubernetes apt repository.

## What you'll build

A fully prepped two-node environment (controlplane + node01) ready for `kubeadm init` in Lab 2. Run every step on **both** nodes unless stated otherwise.

---

## Step 1 — Load kernel modules

The Kubernetes networking stack needs the `br_netfilter` and `overlay` kernel modules.

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
```

`overlay` powers the containerd snapshotter; `br_netfilter` lets iptables see bridged traffic so kube-proxy can NAT it.

---

## Step 2 — Set required sysctls

```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
```

`ip_forward=1` is mandatory: pods on different nodes route through the host.

---

## Step 3 — Disable swap

`kubelet` refuses to start if swap is on (unless you opt in via KubeletConfiguration).

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

---

## Step 4 — Install containerd

```bash
sudo apt update
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

`SystemdCgroup = true` aligns containerd's cgroup driver with the kubelet default — mismatched drivers are the #1 cause of "node NotReady" in fresh clusters.

---

## Step 5 — Install kubeadm, kubelet, kubectl

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

`apt-mark hold` pins the versions so a stray `apt upgrade` cannot break your cluster mid-term.

---

## Step 6 — Verify

```bash
kubeadm version
kubectl version --client
sudo systemctl status containerd --no-pager | head
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock version
```

You should see the `kubeadm` version you noted in Step 0 (for example `v1.37.1`), `containerd` active, and `crictl` reporting the runtime version.

---

> ✅ **Test it:** Both tabs show `kubeadm version` returning the version you noted in Step 0, `containerd` is active, and `kubectl version --client` works — the nodes are ready for `kubeadm init` in Lab 2.
