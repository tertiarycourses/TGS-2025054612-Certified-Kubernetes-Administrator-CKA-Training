# Lab 4 — Cluster Upgrade with kubeadm

In this lab you upgrade a kubeadm cluster by one minor version, following the recommended
order: control plane first, then workers, draining each node before the kubelet restart.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)

> **Which version do I upgrade to?** Nothing in this lab is hard-coded. Step 1 discovers
> what the cluster runs, Step 2 points apt at the next minor and reads the exact package
> version from `apt-cache madison`. If your cluster is already on the newest minor — which
> is what the shared playground gives you — read
> [Already on the newest version?](#already-on-the-newest-version) first.

---

## Step 1 — Check what you are actually running

```bash
kubectl get nodes
kubeadm version -o short
kubelet --version
cat /etc/apt/sources.list.d/kubernetes.list
```

Note two things before you touch anything:

- **The Kubernetes apt repo is pinned to one minor version.** The URL ends in
  `core:/stable:/v1.NN/deb`, and apt can install **only** the versions that one minor
  publishes. Asking for a package from a different minor fails like this:

  ```text
  E: Version '1.35.0-1.1' for 'kubeadm' was not found
  ```

  That is not a broken mirror — it is apt telling you the repo is pointed somewhere else.
  Step 2 repoints it.

- **You cannot upgrade downwards.** Compare `kubeadm version -o short` with the target in
  Step 2. If the cluster is already **newer** than the target (the shared two-node
  playground currently ships `v1.37.x`), skip to
  [Already on the newest version?](#already-on-the-newest-version) instead of installing
  older packages over a running cluster.
---

## Step 2 — Point apt at the target minor, then upgrade the kubeadm binary

Set the target to **exactly one minor above** what Step 1 printed — kubeadm supports one
minor step at a time (v1.34 to v1.35, never v1.34 straight to v1.36):

```bash
TARGET_MINOR=v1.35
sudo sed -i "s|core:/stable:/v1\.[0-9]*|core:/stable:/${TARGET_MINOR}|" \
  /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/${TARGET_MINOR}/deb/Release.key \
  | sudo gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo apt update
apt-cache madison kubeadm | head -3
```

`apt-cache madison` lists the exact package strings that minor publishes, newest first —
for example `1.35.1-1.1`. Never guess this value; read it. Capture it, then install:

```bash
PKG=$(apt-cache madison kubeadm | awk '{print $3}' | head -1)
echo "installing kubeadm=$PKG"
sudo apt-mark unhold kubeadm
sudo apt install -y kubeadm=$PKG
sudo apt-mark hold kubeadm
kubeadm version -o short
```

`kubeadm version -o short` must now show the new version. `$PKG` is used again in Step 5,
so keep this shell open — a new tab or `ssh` session starts without it.

---

## Step 3 — Plan and apply on the control plane

```bash
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply $(kubeadm version -o short) -y
```

`upgrade plan` prints a table of what each component would move to, and refuses if the
jump is unsupported. `upgrade apply` then replaces the static pods in
`/etc/kubernetes/manifests/` one at a time, health-checking between each. On a 1-CPU
playground node this takes several minutes; slow `[upgrade/health]` waits are normal.

---

## Step 4 — Drain the control plane

```bash
kubectl drain controlplane --ignore-daemonsets
```

Drain evicts regular pods so the kubelet restart does not disrupt running workloads.
`--ignore-daemonsets` is required because DaemonSet pods (kube-proxy, the CNI) are
recreated on the node immediately and would otherwise block the drain.

---

## Step 5 — Upgrade kubelet and kubectl on the control plane

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt install -y kubelet=$PKG kubectl=$PKG
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
kubectl uncordon controlplane
```

Lost `$PKG` (new shell)? Re-read it with
`PKG=$(apt-cache madison kubeadm | awk '{print $3}' | head -1)`.

---

## Step 6 — Repeat on the worker

node01 has its own apt config, so repoint its repo too. On **node01**:

```bash
TARGET_MINOR=v1.35
sudo sed -i "s|core:/stable:/v1\.[0-9]*|core:/stable:/${TARGET_MINOR}|" \
  /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/${TARGET_MINOR}/deb/Release.key \
  | sudo gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo apt update
PKG=$(apt-cache madison kubeadm | awk '{print $3}' | head -1)
sudo apt-mark unhold kubeadm && sudo apt install -y kubeadm=$PKG && sudo apt-mark hold kubeadm
sudo kubeadm upgrade node
```

`kubeadm upgrade node` is the worker-side command: it refreshes the kubelet config from
the cluster instead of upgrading control-plane components.

Back on **controlplane**:

```bash
kubectl drain node01 --ignore-daemonsets --delete-emptydir-data
```

On **node01**:

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt install -y kubelet=$PKG kubectl=$PKG
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet
```

On **controlplane**:

```bash
kubectl uncordon node01
kubectl get nodes
```

Both nodes should report the new version.

---

## Already on the newest version?

The shared two-node playground boots a cluster that is already at the newest published
minor, so there is nothing to upgrade *to*. Check for yourself whether the next minor
exists before planning an upgrade — a minor that has not been released yet returns `403`:

```bash
NEXT=v1.38
curl -sL -o /dev/null -w '%{http_code}\n' https://pkgs.k8s.io/core:/stable:/$NEXT/deb/Release.key
```

`200` means that minor is published and you can upgrade to it. `403` means it does not
exist yet — at the time of writing `v1.37` is the newest, so a `v1.37.x` cluster has no
upgrade target. In that case you have two options:

**Option A — practise the procedure without changing versions.** Every command except
`upgrade apply` is safe to run, and `--dry-run` shows exactly what would change:

```bash
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply $(kubeadm version -o short) --dry-run
kubectl drain controlplane --ignore-daemonsets
kubectl uncordon controlplane
```

`upgrade plan` will report that you are already on the latest version — that output *is*
the lesson: this is how you confirm a cluster needs no upgrade.

**Option B — do a real upgrade on a cluster that starts older.** Use this lab's own
KillerCoda scenario, whose `background.sh` provisions a **v1.34** single-node cluster for
exactly this purpose, then run Steps 1-6 with `TARGET_MINOR=v1.35`.

> **Never** "upgrade" by installing older packages over a running cluster. A kubelet older
> than the control plane is unsupported, and the kubelet may refuse to start.

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `E: Version '1.35.0-1.1' for 'kubeadm' was not found` | The apt repo still points at a different minor. Re-run Step 2's `sed` + `apt update`, then read the real string from `apt-cache madison kubeadm`. |
| `kubeadm was already not on hold` | Harmless. `apt-mark unhold` says the package was not pinned. |
| `upgrade plan` says you are on the latest version | Nothing to upgrade. See [Already on the newest version?](#already-on-the-newest-version). |
| `upgrade apply` refuses the version jump | You skipped a minor. Upgrade one minor at a time. |
| Node stays `SchedulingDisabled` after the upgrade | You drained it and never uncordoned it: `kubectl uncordon <node>`. |

---

## What you learned
- The official kubeadm upgrade order: kubeadm binary, `upgrade apply`, drain, kubelet, uncordon.
- That the Kubernetes apt repo is per-minor, and upgrading a minor means repointing it first.
- How to read the exact installable version with `apt-cache madison` instead of guessing.
- Why `apt-mark hold` is unset and re-set around each step.
- How `kubeadm upgrade node` differs from `kubeadm upgrade apply`.
