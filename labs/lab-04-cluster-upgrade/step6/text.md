# Step 6 — Repeat on the worker

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
