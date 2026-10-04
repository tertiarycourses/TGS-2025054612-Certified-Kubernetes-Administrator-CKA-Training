# Lab 2 — Bootstrap a Cluster with kubeadm

In this lab you will turn the two prepared nodes from Lab 1 into a working Kubernetes cluster. You will run `kubeadm init` on the control plane, copy the admin kubeconfig, then join the worker with the bootstrap token.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

---

## Step 0 — Reset the cluster the playground pre-built

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

Confirm the control plane is gone before continuing:

```bash
sudo ls /etc/kubernetes/manifests 2>&1
sudo ss -lntp | grep -E '6443|2379' || echo "API server and etcd ports are free"
```

You want an empty or missing `manifests` directory and free ports.

---

## Step 1 — Initialize the control plane

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

---

## Step 2 — Set up your kubeconfig

Still on **controlplane**:

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes
```

The control plane will show `NotReady` — that's expected until a CNI is installed (Lab 3).

---

## Step 3 — Join the worker

On **node01**, paste the join command from Step 1, prefixed with `sudo`:

```bash
sudo kubeadm join <CONTROLPLANE_IP>:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

If the token expired (24 h TTL), regenerate it on the control plane:

```bash
kubeadm token create --print-join-command
```

---

## Step 4 — Inspect the new cluster

Back on **controlplane**:

```bash
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

You should see two nodes (both `NotReady`) and the static control-plane pods running: `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, `etcd`, plus `kube-proxy` and `coredns`. The CoreDNS pods will stay `Pending` until a CNI is up.

---

## Step 5 — Explore what kubeadm built

```bash
ls /etc/kubernetes/
ls /etc/kubernetes/manifests/
ls /etc/kubernetes/pki/
```

- `manifests/*.yaml` — static pod definitions watched by kubelet.
- `pki/` — the CA, API server, etcd, and service-account keys.
- `admin.conf`, `controller-manager.conf`, `scheduler.conf`, `kubelet.conf` — kubeconfigs for each component.

---

## What you learned
- What `kubeadm init` produces on disk.
- How the worker authenticates with a bootstrap token + CA hash.
- Why nodes are `NotReady` until a CNI plugin runs.
