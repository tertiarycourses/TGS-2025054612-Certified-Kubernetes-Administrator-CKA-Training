# Step 4 — Drain the control plane

```bash
kubectl drain controlplane --ignore-daemonsets
```

**Expected result:** `node/controlplane cordoned`, then `node/controlplane drained`, and
`kubectl get nodes` shows `Ready,SchedulingDisabled`.

Drain evicts regular pods so the kubelet restart does not disrupt running workloads.
`--ignore-daemonsets` is required because DaemonSet pods (kube-proxy, the CNI) are
recreated on the node immediately and would otherwise block the drain.
