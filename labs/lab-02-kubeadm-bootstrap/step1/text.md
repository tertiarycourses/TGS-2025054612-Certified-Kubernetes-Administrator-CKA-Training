# Step 1 — Initialize the control plane

On the **controlplane** node:

```bash
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address=$(hostname -I | awk '{print $1}') \
  --ignore-preflight-errors=NumCPU
```

- `--pod-network-cidr` reserves a non-overlapping range for the CNI plugin (Calico's default).
- `--apiserver-advertise-address` pins the API server to the node's primary IP so workers can reach it.
- `--ignore-preflight-errors=NumCPU` is needed **on this playground only**: `kubeadm` wants
  2 CPUs and the playground node has 1 (the `nproc` you ran in Lab 1). The check is a
  sizing recommendation, not a hard requirement, so the cluster still comes up — just
  slowly. On real hardware, give the control plane 2 CPUs and drop this flag.

If `init` still fails with ports in use or existing manifests, Step 0's reset did not finish —
run it again on this node before retrying.

`kubeadm init` runs preflight checks, generates PKI in `/etc/kubernetes/pki`, writes static-pod manifests in `/etc/kubernetes/manifests`, and prints a `kubeadm join` command at the end. **Copy that join command** — you'll need it in Step 3.
