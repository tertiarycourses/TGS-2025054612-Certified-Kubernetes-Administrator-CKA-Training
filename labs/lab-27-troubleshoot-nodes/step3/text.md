# Step 3 — Break the kubelet config

On **node01**:

```bash
sudo cp /var/lib/kubelet/config.yaml /var/lib/kubelet/config.yaml.bak
sudo sed -i 's/cgroupDriver: systemd/cgroupDriver: cgroupfs/' /var/lib/kubelet/config.yaml
sudo systemctl restart kubelet
sudo journalctl -u kubelet -n 30 --no-pager | grep -i cgroup
```

**Expected result:** the kubelet fails to start cleanly and the journal shows a cgroup
mismatch between the kubelet (`cgroupfs`) and containerd (`SystemdCgroup = true`), with
pods failing to start. The exact wording varies by version — older messages mention docker —
but `cgroup` in the error is the signal.

```bash
sudo systemctl is-active kubelet
kubectl get nodes
```

**Expected result:** from the control plane, `node01` goes `NotReady` again. A cgroup-driver
mismatch is the single most common cause of a node that joins and then never becomes
ready — it is why Lab 1 sets `SystemdCgroup = true`.

Recover:

```bash
sudo cp /var/lib/kubelet/config.yaml.bak /var/lib/kubelet/config.yaml
sudo systemctl restart kubelet
```
