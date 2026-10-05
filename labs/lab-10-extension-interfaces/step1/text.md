# Step 1 — CRI: talk to the runtime directly

`kubelet` talks to the runtime over a Unix socket. `crictl` is the debug client.

> **`crictl: command not found`?** It is not part of containerd or kubeadm — the playground
> image often lacks it. Install it from the same Kubernetes apt repo (see Lab 1, Step 6), or
> use containerd's own CLI, which is always present:
>
> ```bash
> command -v crictl || sudo apt-get install -y cri-tools
> # or, with no install at all:
> sudo ctr -n k8s.io containers ls | head
> ```


```bash
sudo crictl info | head -20
sudo crictl ps
sudo crictl images | head
```

Inspect the kubelet's runtime endpoint:

```bash
sudo grep -E "runtime|cgroup" /var/lib/kubelet/config.yaml
ls /etc/crictl.yaml /run/containerd/containerd.sock 2>/dev/null
```

**Expected result:** `crictl info` prints the runtime's JSON config, `crictl ps` lists the
control-plane containers, and the kubelet config shows `cgroupDriver: systemd` plus a
`containerRuntimeEndpoint`. The socket `/run/containerd/containerd.sock` exists.

> `crictl` talks to the **runtime**, not to Kubernetes — which is why it still works when
> the API server is down. That makes it the tool of choice for the troubleshooting labs.
