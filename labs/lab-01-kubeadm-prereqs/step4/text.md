# Step 4 — Install containerd

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
