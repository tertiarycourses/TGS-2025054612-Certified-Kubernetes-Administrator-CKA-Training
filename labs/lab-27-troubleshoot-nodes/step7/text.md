# Step 7 — Triage checklist

When a node is `NotReady`:
1. `kubectl describe node <name>` — check Conditions.
2. SSH in. `systemctl status kubelet containerd`.
3. `journalctl -u kubelet -u containerd -n 50 --no-pager`.
4. `sudo crictl ps` — runtime sanity check (not installed by default: see Lab 1, Step 6,
   or use `sudo ctr -n k8s.io containers ls`).
5. Disk: `df -h`. Memory: `free -h`. PIDs: `cat /proc/sys/kernel/pid_max` vs `ps -e | wc -l`.
6. Network: `kubectl get pods -A -o wide` — are CNI pods on this node `Running`?
