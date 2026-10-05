# Step 3 — Disable swap

`kubelet` refuses to start if swap is on (unless you opt in via KubeletConfiguration).

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
free -h | grep -i swap
```

**Expected result:** the swap line reads `0B` total. `swapoff` handles the running system
and the `fstab` edit stops it coming back after a reboot — the kubelet refuses to start
with swap on unless you explicitly opt in.
