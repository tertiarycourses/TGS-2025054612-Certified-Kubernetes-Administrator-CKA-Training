# Step 6 — Controller-manager and scheduler

```bash
kubectl -n kube-system logs $(kubectl -n kube-system get pod -l component=kube-controller-manager -o name) | tail
kubectl -n kube-system logs $(kubectl -n kube-system get pod -l component=kube-scheduler -o name) | tail
```

**Expected result:** recent log lines from both components. Right after Step 4 you will
very likely see `leaderelection lost` or `connection refused` entries — they lost their lease
while the API server was down, which is exactly the fingerprint of a control-plane outage in
someone else's logs.

```bash
kubectl -n kube-system get pods -l tier=control-plane -o wide
```

**Expected result:** `etcd`, `kube-apiserver`, `kube-controller-manager` and
`kube-scheduler` all `Running` on the control-plane node.
