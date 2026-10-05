# Lab 4 — Cluster Upgrade with kubeadm

In this lab you upgrade a kubeadm cluster by one minor version, following the recommended
order: control plane first, then workers, draining each node before the kubelet restart.

**Lab environment (recommended):** this lab's own **KillerCoda scenario**, which provisions a **v1.36** single-node cluster so you can upgrade it to **v1.37** for real.
**Alternative:** the [two-node playground](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node) — but it boots at the newest minor, so see [Where to do a real upgrade](#where-to-do-a-real-upgrade) before you start.

> **Which version do I upgrade to?** Nothing in this lab is hard-coded. Step 1 discovers
> what the cluster runs, Step 2 points apt at the next minor and reads the exact package
> version from `apt-cache madison`. If your cluster is already on the newest minor — which
> is what the shared playground gives you — read
> [Where to do a real upgrade](#where-to-do-a-real-upgrade) first.


## What you must be able to show

| Outcome | How you prove it |
|---|---|
| You know the upgrade order | kubeadm binary, `upgrade apply`, drain, kubelet, uncordon — in that order, control plane before workers |
| You can read the cluster's real version | `kubectl get nodes` and `kubeadm version -o short` before and after |
| You can find the installable versions | `apt-cache madison kubeadm` after pointing apt at the right minor |
| You can tell "nothing to upgrade" from "upgrade failed" | `kubeadm upgrade plan` output |
| The node version changed | `kubectl get nodes` shows a **different** `VERSION` than it did in Step 1 |

> **A `--dry-run` never changes a version.** It prints every file it *would* write and ends
> with `Finished dryrunning successfully`, then `kubectl get nodes` still shows the old
> version. That is the flag working as designed, not a failed lab. To see the `VERSION`
> column actually change, you must start from a cluster that is **below** the newest
> release — see [Where to do a real upgrade](#where-to-do-a-real-upgrade).

---

## Step 1 — Check what you are actually running

```bash
kubectl get nodes
kubeadm version -o short
kubelet --version
cat /etc/apt/sources.list.d/kubernetes.list
```

**Expected result:** both nodes `Ready` on the same version, `kubeadm version -o short`
and `kubelet --version` agreeing, and a sources list ending in `core:/stable:/v1.NN/deb`.

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
  [Where to do a real upgrade](#where-to-do-a-real-upgrade) instead of installing
  older packages over a running cluster.
---

## Step 2 — Point apt at the target minor, then upgrade the kubeadm binary

Set the target to **exactly one minor above** what Step 1 printed — kubeadm supports one
minor step at a time (v1.36 to v1.37, never v1.35 straight to v1.37). The example below
uses `v1.37`: that is the newest published minor, the one the shared playground already
runs, and the target for this lab's KillerCoda scenario, which provisions a **v1.36**
cluster for you:

```bash
TARGET_MINOR=v1.37          # one minor above what Step 1 printed
LIST=/etc/apt/sources.list.d/kubernetes.list
KEYRING=$(grep -oE '/etc/apt/keyrings/[^] ]+\.gpg' $LIST)
echo "list=$LIST keyring=$KEYRING target=$TARGET_MINOR"

sudo sed -i "s|core:/stable:/v1\.[0-9]*|core:/stable:/${TARGET_MINOR}|" $LIST
curl -fsSL https://pkgs.k8s.io/core:/stable:/${TARGET_MINOR}/deb/Release.key \
  | sudo gpg --yes --dearmor -o "$KEYRING"
sudo apt update
apt-cache madison kubeadm | head -3
```

> **Why `$KEYRING` instead of a fixed filename?** The list line names its own keyring in
> `signed-by=`, and the name includes the minor — on this playground it is
> `/etc/apt/keyrings/kubernetes-1-37-apt-keyring.gpg`. Writing the key to any other file
> leaves the repo unverifiable and `apt update` fails, so read the path out of the list
> file rather than assuming it.

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

**Expected result:** `upgrade plan` prints a table of current versus target version for
each component, and `upgrade apply` ends with
`SUCCESS! Your cluster was upgraded to "vX.Y.Z". Enjoy!`.

`upgrade plan` refuses an unsupported jump before anything changes. `upgrade apply` then replaces the static pods in
`/etc/kubernetes/manifests/` one at a time, health-checking between each. On a 1-CPU
playground node this takes several minutes; slow `[upgrade/health]` waits are normal.

---

## Step 4 — Drain the control plane

```bash
kubectl drain controlplane --ignore-daemonsets
```

**Expected result:** `node/controlplane cordoned`, then `node/controlplane drained`, and
`kubectl get nodes` shows `Ready,SchedulingDisabled`.

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

**Expected result:** the packages install, the kubelet restarts, and
`node/controlplane uncordoned`. Confirm the node now reports the new version:

```bash
kubectl get nodes
```

**Expected result:** the control plane's `VERSION` column shows the version you upgraded
to — the first visible proof the upgrade worked.

Lost `$PKG` (new shell)? Re-read it with
`PKG=$(apt-cache madison kubeadm | awk '{print $3}' | head -1)`.

---

## Step 6 — Repeat on the worker

> **Single-node environment?** The KillerCoda scenario runs one node, which has already
> been upgraded by Step 5 — there is no `node01`, so skip to the verification below.

node01 has its own apt config, so repoint its repo too. On **node01**:

```bash
TARGET_MINOR=v1.37          # one minor above what Step 1 printed
LIST=/etc/apt/sources.list.d/kubernetes.list
KEYRING=$(grep -oE '/etc/apt/keyrings/[^] ]+\.gpg' $LIST)
echo "list=$LIST keyring=$KEYRING target=$TARGET_MINOR"

sudo sed -i "s|core:/stable:/v1\.[0-9]*|core:/stable:/${TARGET_MINOR}|" $LIST
curl -fsSL https://pkgs.k8s.io/core:/stable:/${TARGET_MINOR}/deb/Release.key \
  | sudo gpg --yes --dearmor -o "$KEYRING"
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

## Where to do a real upgrade

`kubeadm` can only move a cluster **forwards**, and only one minor at a time. So a real
upgrade needs a cluster that starts *below* the newest release. Check what the newest
published minor is before you plan anything — an unreleased minor returns `403`:

```bash
NEXT=v1.38
curl -sL -o /dev/null -w '%{http_code}\n' https://pkgs.k8s.io/core:/stable:/$NEXT/deb/Release.key
```

`200` means that minor exists and is a valid target. `403` means it does not exist yet — at
the time of writing `v1.37` is the newest, so a `v1.37.x` cluster has nothing to upgrade to.
The shared two-node playground boots at that newest minor, which is why the options below
matter.

### Option A — this lab's KillerCoda scenario (recommended: a real v1.36 to v1.37 upgrade)

The scenario provisions its **own single-node v1.36 cluster** in the background, so you
upgrade a genuinely older cluster and watch the minor change. Nothing needs rebuilding and
no downgrade tricks are involved.

1. Open the scenario (KillerCoda profile `tertiary-labs-cka`, Lab 04) and wait for
   provisioning to finish — it takes a couple of minutes:

   ```bash
   until [ -f /tmp/cluster-ready ]; do sleep 5; done; echo READY
   cat /tmp/cluster-start-version.txt     # v1.36.x  <- your "before"
   kubectl get nodes
   ```

2. Work through **Steps 1 to 5** with `TARGET_MINOR=v1.37`.
3. Confirm the change:

   ```bash
   cat /tmp/cluster-before.txt             # captured at provisioning time
   kubectl get nodes                       # VERSION v1.37.x  <- your "after"
   ```

The scenario is a single node, so skip Step 6 (the worker) there — `kubectl get nodes`
reporting the new minor is the finish line.

### Option B — patch upgrade on the shared playground (v1.37.0 to v1.37.1)

If you are on the two-node playground and want a real version change without a second
environment, rebuild one patch lower. The v1.37 repo publishes both `1.37.0-1.1` and
`1.37.1-1.1`, so no repo repoint is needed.

Run on **both** nodes — this destroys the cluster you built in Lab 2:

```bash
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/etcd /etc/cni/net.d $HOME/.kube
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt install -y --allow-downgrades \
  kubeadm=1.37.0-1.1 kubelet=1.37.0-1.1 kubectl=1.37.0-1.1
sudo apt-mark hold kubeadm kubelet kubectl
sudo systemctl restart containerd
kubeadm version -o short          # v1.37.0
```

`--allow-downgrades` is required because these packages are older than the ones on disk.
It is safe only because you reset the cluster first — never install older packages under a
live control plane.

Bootstrap at that version on **controlplane**:

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address=$(hostname -I | awk '{print $1}') \
  --kubernetes-version=v1.37.0 --ignore-preflight-errors=NumCPU
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes                 # VERSION v1.37.0  <- your "before"
```

Then run **Steps 2 to 5** with `TARGET_MINOR=v1.37`: `apt-cache madison` lists
`1.37.1-1.1` as its newest entry, so `$PKG` becomes that, and you finish on **v1.37.1**.

### Option C — minor upgrade on the shared playground (v1.36 to v1.37)

Same as Option B, but start one *minor* lower so Step 2's repo repoint genuinely matters.
Point apt at **v1.36** and see what it offers:

```bash
TARGET_MINOR=v1.36
LIST=/etc/apt/sources.list.d/kubernetes.list
KEYRING=$(grep -oE '/etc/apt/keyrings/[^] ]+\.gpg' $LIST)
sudo sed -i "s|core:/stable:/v1\.[0-9]*|core:/stable:/${TARGET_MINOR}|" $LIST
curl -fsSL https://pkgs.k8s.io/core:/stable:/${TARGET_MINOR}/deb/Release.key \
  | sudo gpg --yes --dearmor -o "$KEYRING"
sudo apt update
apt-cache madison kubeadm | head -3        # newest v1.36 patch, e.g. 1.36.5-1.1
```

Reset both nodes as in Option B, install that `1.36.x` trio with `--allow-downgrades`,
run `kubeadm init --kubernetes-version=v1.36.<patch>`, then work through Steps 2 to 6 with
`TARGET_MINOR=v1.37`. You end on v1.37.x having done the whole exercise: repo repoint,
control plane, drain, kubelet, worker.

### Option D — procedure only, no version change

On a cluster already at the newest minor, every command except `upgrade apply` still runs,
and `--dry-run` shows exactly what would change:

```bash
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply $(kubeadm version -o short) --dry-run
kubectl drain controlplane --ignore-daemonsets
kubectl uncordon controlplane
kubectl get nodes
```

`upgrade plan` reports you are already on the latest version and `get nodes` shows the
**same** version as before. Useful for rehearsing the commands, and it is how you confirm
in production that a cluster needs no upgrade — but it does **not** demonstrate an upgrade.
Use Option A for that.

> **Never** "upgrade" by installing older packages over a *running* cluster. A kubelet
> older than the control plane is unsupported and may refuse to start. Options B and C
> install older packages only after `kubeadm reset` has torn the cluster down.

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `E: Version '1.35.0-1.1' for 'kubeadm' was not found` | The apt repo still points at a different minor. Re-run Step 2's `sed` + `apt update`, then read the real string from `apt-cache madison kubeadm`. |
| `kubeadm was already not on hold` | Harmless. `apt-mark unhold` says the package was not pinned. |
| `upgrade plan` says you are on the latest version | Nothing to upgrade. See [Where to do a real upgrade](#where-to-do-a-real-upgrade). |
| `--dry-run` finished but `kubectl get nodes` shows the old version | Correct: a dry run writes nothing. Use Option A (the scenario's v1.36 cluster) to see the version change. |
| `upgrade apply` refuses the version jump | You skipped a minor. Upgrade one minor at a time. |
| Node stays `SchedulingDisabled` after the upgrade | You drained it and never uncordoned it: `kubectl uncordon <node>`. |

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — starting state | both nodes `Ready`, versions agreeing, repo pinned to one minor |
| Step 2 — repo + binary | `apt-cache madison` lists the target; `kubeadm version` shows it |
| Step 3 — plan and apply | `SUCCESS! Your cluster was upgraded` |
| Step 4 — drain | `Ready,SchedulingDisabled` |
| Step 5 — kubelet | node `VERSION` shows the new version after uncordon |
| Step 6 — worker | both nodes on the new version |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `E: Version '…' for 'kubeadm' was not found` | The apt repo still points at another minor. Re-run Step 2's `sed` and `apt update`. |
| `apt update` fails to verify the repo | The key went to the wrong file — Step 2 reads the keyring path out of `signed-by=`. |
| `upgrade plan` says you are on the latest version | Nothing to upgrade here — see **Where to do a real upgrade**. |
| `upgrade apply` refuses the version jump | You skipped a minor; upgrade one at a time. |
| Node still shows the old version after Step 5 | The kubelet package was not upgraded or not restarted: `sudo systemctl restart kubelet`. |
| Node left `SchedulingDisabled` | You drained and never uncordoned: `kubectl uncordon <node>`. |

---

## What you learned
- The official kubeadm upgrade order: kubeadm binary, `upgrade apply`, drain, kubelet, uncordon.
- That the Kubernetes apt repo is per-minor, and upgrading a minor means repointing it first.
- How to read the exact installable version with `apt-cache madison` instead of guessing.
- Why `apt-mark hold` is unset and re-set around each step.
- How `kubeadm upgrade node` differs from `kubeadm upgrade apply`.
