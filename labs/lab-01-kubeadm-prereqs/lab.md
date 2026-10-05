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

**Expected result:** the file contents are echoed back, and both `modprobe` commands
return silently. Confirm they are loaded:

```bash
lsmod | grep -E "^overlay|^br_netfilter"
```

**Expected result:** both modules listed. `overlay` powers the containerd snapshotter;
`br_netfilter` lets iptables see bridged traffic so kube-proxy can NAT it. The file in
`/etc/modules-load.d/` makes this survive a reboot — the `modprobe` only affects now.

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

**Expected result:** `sysctl --system` prints every file it reads, ending with your three
settings. Verify the live values:

```bash
sysctl net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables
```

**Expected result:** both `= 1`. `ip_forward=1` is mandatory: pods on different nodes route
through the host, and with forwarding off cross-node traffic is silently dropped.

---

## Step 3 — Disable swap

`kubelet` refuses to start if swap is on (unless you opt in via KubeletConfiguration).

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
free -h | grep -i swap
```

**Expected result:** the swap line reads `0B` total. `swapoff` handles the running system
and the `fstab` edit stops it coming back after a reboot — the kubelet refuses to start
with swap on unless you explicitly opt in.

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

**Expected result:** containerd is `active (running)` and the setting took:

```bash
sudo grep SystemdCgroup /etc/containerd/config.toml
systemctl is-active containerd
```

**Expected result:** `SystemdCgroup = true` and `active`.

`SystemdCgroup = true` aligns containerd's cgroup driver with the kubelet default —
mismatched drivers are the number one cause of "node NotReady" in fresh clusters, and you
will break it deliberately in Lab 27 to see the symptom.

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

**Expected result:** the three packages install and `apt-mark` reports
`kubelet set on hold`, `kubeadm set on hold`, `kubectl set on hold`.

`apt-mark hold` pins the versions so a stray `apt upgrade` cannot break your cluster
mid-term — and it is why Lab 4's upgrade starts with `apt-mark unhold`.

---

## Step 6 — Install crictl, then verify

`crictl` is the CRI debug client, and it is **not** installed by containerd or kubeadm — on
this playground it is missing entirely (`crictl: command not found`). Labs 5, 10, 26 and 27
depend on it, because it is the only way to inspect containers when the API server is down.

```bash
sudo apt-get update -qq && sudo apt-get install -y cri-tools
crictl --runtime-endpoint unix:///run/containerd/containerd.sock version
```

**Expected result:** `crictl` prints its version plus the runtime's
(`RuntimeName: containerd`).

`cri-tools` is published in the same `pkgs.k8s.io` repository as `kubeadm`, so the apt
source from Step 5 already covers it. If apt cannot find the package, take the binary from
the release instead:

```bash
VER=v1.37.0
curl -sL "https://github.com/kubernetes-sigs/cri-tools/releases/download/$VER/crictl-$VER-linux-amd64.tar.gz" \
  | sudo tar -xz -C /usr/local/bin crictl
crictl --version
```

> Set the endpoint once so you can drop the flag everywhere else:
>
> ```bash
> sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock
> ```
>
> Without it, newer `crictl` still works but warns on every call. There is always a
> fallback that needs no install, because it ships with containerd itself:
> `sudo ctr -n k8s.io containers ls`.

Now verify the whole set:

```bash
kubeadm version
kubectl version --client
systemctl is-active containerd
sudo crictl ps | head
```

You should see the `kubeadm` version you noted in Step 0 (for example `v1.37.1`), `containerd` active, and `crictl` reporting the runtime version.

---

> ✅ **Test it:** Both tabs show `kubeadm version` returning the version you noted in Step 0, `containerd` is active, and `kubectl version --client` works — the nodes are ready for `kubeadm init` in Lab 2.

---

## Verification

| Check | Expected |
|---|---|
| Step 0 — what you already have | a `kubeadm` version and `nproc` noted; whether a cluster is already running |
| Step 1 — modules | `overlay` and `br_netfilter` in `lsmod` |
| Step 2 — sysctls | `net.ipv4.ip_forward = 1`, `bridge-nf-call-iptables = 1` |
| Step 3 — swap | `free -h` shows `0B` swap |
| Step 4 — containerd | `active`, with `SystemdCgroup = true` |
| Step 5 — binaries | all three packages installed and held |
| Step 6 — verify | `kubeadm version` matches Step 0, containerd active, crictl answers |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `modprobe: FATAL: Module not found` | An unusual kernel without the module built in. Check `uname -r` and the distro's `linux-modules-extra` package. |
| `sysctl: cannot stat /proc/sys/net/bridge/...` | `br_netfilter` is not loaded yet — run Step 1 first, then re-run `sysctl --system`. |
| kubelet refuses to start, mentioning swap | `sudo swapoff -a`, and check `/etc/fstab` has the swap line commented. |
| `apt install containerd` fails on an internal network | The playground has internet; a locked-down VM needs a mirror or a pre-pulled package. |
| `apt` cannot find kubelet/kubeadm | The `pkgs.k8s.io` repo line or its keyring is wrong — re-run Step 5 and check `/etc/apt/sources.list.d/kubernetes.list`. |
| Versions differ from Step 0's note | You installed a different minor over a running cluster. Do not — see Step 0's version note. |
