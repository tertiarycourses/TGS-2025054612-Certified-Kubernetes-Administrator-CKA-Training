#!/bin/bash
# Provision a single-node Kubernetes cluster ONE MINOR BELOW the newest release,
# so the student performs a real v1.36 -> v1.37 upgrade in this scenario.
# Runs while the student reads the intro; /tmp/cluster-ready signals completion.
set -euo pipefail

START_MINOR=v1.36                                   # the lab upgrades this to v1.37
KEYRING=/etc/apt/keyrings/kubernetes-apt-keyring.gpg
LIST=/etc/apt/sources.list.d/kubernetes.list
export DEBIAN_FRONTEND=noninteractive

log() { echo "[background] $*"; }

# ── kernel prereqs ────────────────────────────────────────────────────────────
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system > /dev/null

swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# ── containerd ────────────────────────────────────────────────────────────────
apt-get update -qq
apt-get install -y -qq containerd apt-transport-https ca-certificates curl gpg
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml > /dev/null
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# ── kubeadm / kubelet / kubectl from the START_MINOR repo ─────────────────────
# Newest patch of that minor; no version is pinned here, so this script keeps
# working as patches are published. The apt repo serves one minor at a time,
# which is why the lab repoints it in Step 2 before upgrading.
mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${START_MINOR}/deb/Release.key" \
  | gpg --yes --dearmor -o "$KEYRING"
echo "deb [signed-by=$KEYRING] https://pkgs.k8s.io/core:/stable:/${START_MINOR}/deb/ /" \
  | tee "$LIST"
apt-get update -qq
apt-get install -y -qq kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
log "installed kubeadm $(kubeadm version -o short)"

# ── bootstrap the control plane ───────────────────────────────────────────────
# No --kubernetes-version: kubeadm bootstraps its own version, so the control
# plane and the binary can never disagree about the patch level.
kubeadm init --pod-network-cidr=10.244.0.0/16 \
  --ignore-preflight-errors=NumCPU,Mem 2>&1 | tee /tmp/kubeadm-init.log

mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chmod 600 /root/.kube/config

# Single-node cluster: let workloads schedule on the control plane.
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

# ── Flannel CNI (matches the pod CIDR above) ──────────────────────────────────
kubectl apply -f \
  https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# ── record the starting state, so "before and after" is checkable ─────────────
kubeadm version -o short > /tmp/cluster-start-version.txt
kubectl get nodes -o wide > /tmp/cluster-before.txt 2>&1 || true
touch /tmp/cluster-ready
log "cluster ready at $(cat /tmp/cluster-start-version.txt)"
