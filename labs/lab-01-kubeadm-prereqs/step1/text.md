# Step 1 — Load kernel modules

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
