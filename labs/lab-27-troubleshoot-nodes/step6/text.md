# Step 6 — Container runtime down

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
