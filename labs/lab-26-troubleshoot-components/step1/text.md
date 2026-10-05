# Step 1 — Map components to their on-disk source

```bash
sudo ls /etc/kubernetes/manifests/
```

Each YAML is a **static pod** the kubelet watches and runs:
- `kube-apiserver.yaml`
- `kube-controller-manager.yaml`
- `kube-scheduler.yaml`
- `etcd.yaml`

```bash
sudo systemctl status kubelet --no-pager | head
sudo systemctl status containerd --no-pager | head
```

**Expected result:** four manifests in `/etc/kubernetes/manifests/`, and both
`kubelet` and `containerd` reported `active (running)`.

The split matters when things break: the control plane runs as **static pods** the kubelet
starts from those files (no Deployment, no scheduler involved), while the kubelet and
containerd are **systemd services**. So a broken control-plane component is a file problem,
and a dead kubelet is a systemd problem.
