# Step 2 — Stop the kubelet

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
