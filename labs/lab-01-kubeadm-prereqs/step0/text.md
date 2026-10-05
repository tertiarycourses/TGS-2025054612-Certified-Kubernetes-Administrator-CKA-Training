# Step 0 — Check what the playground already gives you

The KillerCoda playground is **not** a bare Ubuntu box: it boots with containerd,
`kubeadm`, `kubelet` and `kubectl` already installed **and a cluster already running**.
Find out what you have before you change anything — on **both tabs**:

```bash
kubeadm version -o short || echo "kubeadm NOT installed"
nproc
kubectl get nodes 2>/dev/null || echo "no cluster reachable from this node"
```

Then pick your path:

| What you see | What to do |
|---|---|
| A version (e.g. `v1.37.1`) **and** `kubectl get nodes` lists nodes | The prerequisites are already in place. **Read** Steps 1–5 to learn what each one does, run **Step 6** to verify, then go to Lab 2, which resets the cluster so you bootstrap it yourself. |
| `kubeadm NOT installed` (a bare Ubuntu node) | Run Steps 1–5, then Step 6. |

Write down the version `kubeadm version` printed and the `nproc` count — you need the
version in Lab 4 (upgrade) and the CPU count in Lab 2.

> **Version note:** Step 5 below pins the **v1.35** package repo, but the playground
> currently ships a newer Kubernetes (**v1.37.x**). That is expected. Never mix: if a
> cluster is already running, do not install different `kubeadm`/`kubelet` versions over
> it, or `kubeadm init` and the kubelet will disagree about the version to use.

---

## Goal

Prepare two clean Ubuntu nodes for a Kubernetes cluster install: load the required kernel modules, apply the right sysctls, install `containerd` as the Container Runtime Interface (CRI), and install the `kubeadm`, `kubelet`, and `kubectl` binaries from the official Kubernetes apt repository.

## What you'll build

A fully prepped two-node environment (controlplane + node01) ready for `kubeadm init` in Lab 2. Run every step on **both** nodes unless stated otherwise.
