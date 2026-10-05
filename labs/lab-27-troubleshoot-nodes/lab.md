# Lab 27 — Troubleshoot Nodes

Nodes go `NotReady` when the kubelet can't report healthy. In this lab you simulate three common node-level failures and recover from each.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Baseline

```bash
kubectl get nodes
kubectl describe node node01 | grep -E "Conditions|Taints" -A6
```

**Expected result:** `node01` is `Ready`, with `MemoryPressure`, `DiskPressure` and
`PIDPressure` all `False` and no taints.

Those are the five conditions the kubelet reports: `Ready`, `MemoryPressure`,
`DiskPressure`, `PIDPressure`, `NetworkUnavailable`. "False" is the healthy value for the
pressure conditions — a `True` there is the kubelet asking for help.

---

## Step 2 — Stop the kubelet

On **node01**:

```bash
sudo systemctl stop kubelet
```

Back on **controlplane**, the node does not flip instantly — the control plane waits
`node-monitor-grace-period` (40s by default) before distrusting it:

```bash
sleep 45
kubectl get nodes
kubectl describe node node01 | grep -A3 "Ready "
```

**Expected result:** `node01` is `NotReady`, and the Ready condition's message reads
`Kubelet stopped posting node status`.

Note what does **not** happen: existing pods keep running. The kubelet is gone, so nobody
reports on them, and only after ~5 minutes does the controller start evicting.

Fix:

```bash
# on node01
sudo systemctl start kubelet
sudo journalctl -u kubelet -n 20 --no-pager
```

---

## Step 3 — Break the kubelet config

On **node01**:

```bash
sudo cp /var/lib/kubelet/config.yaml /var/lib/kubelet/config.yaml.bak
sudo sed -i 's/cgroupDriver: systemd/cgroupDriver: cgroupfs/' /var/lib/kubelet/config.yaml
sudo systemctl restart kubelet
sudo journalctl -u kubelet -n 30 --no-pager | grep -i cgroup
```

**Expected result:** the kubelet fails to start cleanly and the journal shows a cgroup
mismatch between the kubelet (`cgroupfs`) and containerd (`SystemdCgroup = true`), with
pods failing to start. The exact wording varies by version — older messages mention docker —
but `cgroup` in the error is the signal.

```bash
sudo systemctl is-active kubelet
kubectl get nodes
```

**Expected result:** from the control plane, `node01` goes `NotReady` again. A cgroup-driver
mismatch is the single most common cause of a node that joins and then never becomes
ready — it is why Lab 1 sets `SystemdCgroup = true`.

Recover:

```bash
sudo cp /var/lib/kubelet/config.yaml.bak /var/lib/kubelet/config.yaml
sudo systemctl restart kubelet
```

---

## Step 4 — Cordon and drain

Sometimes you need to take a node out of service safely.

```bash
kubectl cordon node01
kubectl get nodes
kubectl drain node01 --ignore-daemonsets --delete-emptydir-data
```

**Expected result:** after `cordon`, `node01` shows `Ready,SchedulingDisabled` — it keeps
running what it has but accepts nothing new. `drain` then evicts the rest and prints
`node/node01 drained`.

```bash
kubectl get pods -A -o wide | grep node01
```

**Expected result:** only DaemonSet pods (CNI, kube-proxy) remain — `--ignore-daemonsets`
leaves them because they are recreated on the node immediately. `uncordon` returns the node
to `Ready`.

> `drain` is `cordon` **plus** eviction, and it respects PodDisruptionBudgets — which is why
> it can hang on a real cluster.

Bring it back:

```bash
kubectl uncordon node01
```

---

## Step 5 — Disk pressure simulation

⚠️ **Read before running.** Filling a disk can wedge a node so badly that even the
kubelet cannot recover. A blind `fallocate -l 5G` may consume *all* free space on a small
playground disk. Size the file from what is actually free, leaving a margin, and delete it
in the same step.

```bash
# on node01
df -h /var | tail -1
AVAIL_MB=$(df -m --output=avail /var | tail -1 | tr -d ' ')
FILL_MB=$(( AVAIL_MB * 70 / 100 ))
echo "available ${AVAIL_MB}MB -> filling ${FILL_MB}MB"
sudo fallocate -l ${FILL_MB}M /var/big.fill
df -h /var | tail -1
```

**Expected result:** `/var` usage jumps but stays short of 100%.

Watch the kubelet react from **controlplane** (eviction thresholds are evaluated on the
kubelet's housekeeping interval, so allow a minute):

```bash
sleep 60
kubectl describe node node01 | grep -A2 DiskPressure
kubectl get events -A --field-selector reason=NodeHasDiskPressure
kubectl describe node node01 | grep -i taints
```

**Expected result:** `DiskPressure` may flip to `True`, with a `NodeHasDiskPressure` event
and a `node.kubernetes.io/disk-pressure:NoSchedule` taint. If 70% of free space was not
enough to cross the default 85% threshold, the condition stays `False` — the mechanism is
the lesson, not the number.

**Recover immediately — do not leave this file in place:**

```bash
# on node01
sudo rm -f /var/big.fill
df -h /var | tail -1
```

**Expected result:** space returned, and within a minute `DiskPressure` is `False` and the
taint is gone.

---

## Step 6 — Container runtime down

```bash
# on node01
sudo systemctl stop containerd
kubectl get nodes
sudo journalctl -u kubelet -n 10 --no-pager
sudo systemctl start containerd
```

**Expected result:** the node flips to `NotReady` within ~40 seconds and the kubelet
journal repeats CRI errors such as
`failed to get container runtime status … connection refused`. It returns to `Ready` a few
seconds after containerd starts.

The kubelet cannot function without a container runtime: no runtime, no container statuses,
no node status. `systemctl status kubelet containerd` on a `NotReady` node is always the
right first move.

---

## Step 7 — Triage checklist

When a node is `NotReady`:
1. `kubectl describe node <name>` — check Conditions.
2. SSH in. `systemctl status kubelet containerd`.
3. `journalctl -u kubelet -u containerd -n 50 --no-pager`.
4. `sudo crictl ps` — runtime sanity check.
5. Disk: `df -h`. Memory: `free -h`. PIDs: `cat /proc/sys/kernel/pid_max` vs `ps -e | wc -l`.
6. Network: `kubectl get pods -A -o wide` — are CNI pods on this node `Running`?

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — baseline | `node01` Ready, pressure conditions `False`, no taints |
| Step 2 — kubelet stopped | `NotReady` after ~40s with `Kubelet stopped posting node status` |
| Step 3 — bad cgroup driver | kubelet errors mentioning `cgroup`; node `NotReady` until reverted |
| Step 4 — cordon/drain | `Ready,SchedulingDisabled`, then only DaemonSet pods left |
| Step 5 — disk pressure | usage rises; `DiskPressure`/taint may appear, then clears after `rm` |
| Step 6 — runtime down | `NotReady` with CRI `connection refused`, recovering on restart |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Node does not go `NotReady` immediately | Expected: the control plane waits ~40s (`node-monitor-grace-period`). |
| Node stays `NotReady` after reverting Step 3 | Restart the kubelet and check the journal: `sudo systemctl restart kubelet`, `journalctl -u kubelet -n 50`. |
| `drain` hangs | A PodDisruptionBudget or an unmanaged pod is blocking it; add `--force` only when you understand what it kills. |
| Disk filled completely and the node is stuck | `sudo rm -f /var/big.fill` immediately; if the kubelet is wedged, restart it afterwards. |
| `DiskPressure` never becomes True | Free space never crossed the 85% threshold — fine, the taint mechanism is the point. |
| `fallocate: command not found` | Use `sudo dd if=/dev/zero of=/var/big.fill bs=1M count=$FILL_MB` instead. |

---

## What you learned
- kubelet + containerd are the node's lifeline.
- Five node conditions and the symptoms that trigger each.
- Cordon, drain, uncordon for planned maintenance.
