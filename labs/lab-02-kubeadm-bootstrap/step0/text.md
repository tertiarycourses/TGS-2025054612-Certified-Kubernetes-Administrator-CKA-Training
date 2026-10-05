# Step 0 — Reset the cluster the playground pre-built

The KillerCoda playground boots with a **working cluster already installed**. `kubeadm init`
refuses to run on a node that is already a control plane, so it fails like this:

```text
[ERROR Port-6443]: Port 6443 is in use
[ERROR FileAvailable--etc-kubernetes-manifests-kube-apiserver.yaml]: ... already exists
[ERROR DirAvailable--var-lib-etcd]: /var/lib/etcd is not empty
[ERROR NumCPU]: the number of available CPUs 1 is less than the required 2
```

That is not a broken lab — it is the environment telling you a cluster is already there.
Tear it down so you can build it yourself. Run this on **both** tabs (controlplane *and*
node01):

```bash
kubectl get nodes 2>/dev/null || true
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/etcd /etc/cni/net.d $HOME/.kube
sudo systemctl restart containerd
```

- `kubeadm reset -f` stops the static pods, drains etcd's member list and removes the
  kubeconfigs and PKI that `kubeadm init` would refuse to overwrite (`-f` skips the prompt).
- The `rm -rf` clears what reset deliberately leaves behind: a non-empty `/var/lib/etcd`
  or a stale CNI config in `/etc/cni/net.d` would break the new cluster.
- On a node that was never initialised, these commands are harmless — `reset` just reports
  there is nothing to do.

> **The red `StopPodSandbox ... DeadlineExceeded` lines are expected.** `reset` asks
> containerd to stop the old pods and gives up after a few tries when a sandbox is slow to
> die on a 1-CPU node (`Failed to remove containers`). It still deletes `/var/lib/etcd`,
> `/etc/kubernetes` and the kubelet state, and the `systemctl restart containerd` above
> clears the stuck sandbox. The two checks below are what decide whether reset worked.

Confirm the control plane is gone before continuing:

```bash
sudo ls /etc/kubernetes/manifests 2>&1
sudo ss -lntp | grep -E '6443|2379' || echo "API server and etcd ports are free"
```

You want an empty or missing `manifests` directory and free ports.
