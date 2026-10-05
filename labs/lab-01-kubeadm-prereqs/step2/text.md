# Step 2 — Set required sysctls

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
