# Step 5 — Disk pressure simulation

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
