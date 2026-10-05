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

**Expected result:** `kubectl get nodes` lists the control plane as **`NotReady`**.

That is correct, not a failure: there is no pod network yet, so the kubelet reports
`container runtime network not ready`. Lab 3 installs a CNI and the node flips to `Ready`.

> If `kubectl` instead says `The connection to the server localhost:8080 was refused`, the
> kubeconfig copy above did not happen — re-run those three commands.

---

## Step 3 — Join the worker

Switch to your **node01** tab (or run `ssh node01` from the control plane).

**Reset node01 first.** It was part of the cluster the playground pre-built, so the join
is refused while its old kubelet config and CA sit on disk:

```text
[ERROR FileAvailable--etc-kubernetes-kubelet.conf]: /etc/kubernetes/kubelet.conf already exists
[ERROR FileAvailable--etc-kubernetes-pki-ca.crt]: /etc/kubernetes/pki/ca.crt already exists
[ERROR Port-10250]: Port 10250 is in use
```

```bash
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/etcd /etc/cni/net.d $HOME/.kube
sudo systemctl restart containerd
```

Now join the worker. **Do not copy the template below** - it only shows the shape of the
command. Paste the real `kubeadm join` line that `kubeadm init` printed at the end of
Step 1, with your own IP, token and hash. Pasting the placeholders fails with
`bash: syntax error near unexpected token 'newline'`, because the shell reads `<` and `>`
as redirections:

```bash
sudo kubeadm join <CONTROLPLANE_IP>:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

Lost that line, or is the token past its 24 h TTL? Print a fresh one **on the control
plane** and run the command it gives you on node01:

```bash
kubeadm token create --print-join-command
```

A successful join ends with `This node has joined the cluster`.

---

## Step 4 — Inspect the new cluster

Back on **controlplane**:

```bash
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

**Expected result:** two nodes, both `NotReady`, and in `kube-system`:
`kube-apiserver`, `kube-controller-manager`, `kube-scheduler` and `etcd` all `Running`,
`kube-proxy` on both nodes, and **CoreDNS `Pending`**.

CoreDNS is the tell-tale: it needs a pod IP, and no CNI means no pod network, so it cannot
start. Everything else in the control plane runs with `hostNetwork: true` and does not
care. Fix both by installing a CNI in Lab 3.

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

**Expected result:** `manifests/` holds the four static-pod YAMLs, `pki/` holds `ca.crt`,
`apiserver.crt`, the `etcd/` sub-directory and `sa.key`, and the four kubeconfigs sit in
`/etc/kubernetes/`.

Worth remembering for the troubleshooting labs: **everything the control plane needs is
these files**. Lab 26 breaks one on purpose, and Lab 5 backs up the data behind them.

---

## Verification

| Check | Expected |
|---|---|
| Step 0 — reset | `manifests` empty or missing; ports 6443/2379 free |
| Step 1 — init | `Your Kubernetes control-plane has initialized successfully!` plus two join commands |
| Step 2 — kubeconfig | control plane listed as `NotReady` |
| Step 3 — join | `This node has joined the cluster` on node01 |
| Step 4 — inspect | two `NotReady` nodes; control-plane pods Running; CoreDNS `Pending` |
| Step 5 — on disk | four manifests, the PKI, and four kubeconfigs |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `localhost:8080 ... connection refused` | kubectl has no kubeconfig — copy `admin.conf` as in Step 2. |
| `Port 6443 is in use` / manifests exist | A cluster is already running. Re-run Step 0's reset on that node. |
| `NumCPU 1 is less than the required 2` | Add `--ignore-preflight-errors=NumCPU` — the playground has 1 CPU. |
| Nodes stay `NotReady` | Expected until Lab 3 installs a CNI; confirm with `kubectl describe node | grep -i network`. |
| `bash: syntax error near unexpected token 'newline'` | You pasted the `<token>`/`<hash>` template. Use the real join command printed by `init`. |
| Join fails on existing kubelet.conf or port 10250 | node01 was part of the old cluster — reset it first (Step 3). |
| Token expired (after 24h) | `kubeadm token create --print-join-command` on the control plane. |

---

## What you learned
- What `kubeadm init` produces on disk.
- How the worker authenticates with a bootstrap token + CA hash.
- Why nodes are `NotReady` until a CNI plugin runs.
