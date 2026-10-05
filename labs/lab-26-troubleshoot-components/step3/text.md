# Step 3 — Diagnose

The API is gone, so use container-level tools.

```bash
sudo crictl ps -a | grep apiserver
sudo crictl logs $(sudo crictl ps -a | grep apiserver | awk '{print $1}' | head -1) 2>&1 | tail -20
sudo journalctl -u kubelet --no-pager | tail -30
sudo ls /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/
```

**Expected result:** `crictl ps -a` lists the apiserver container repeatedly `Exited`, and
the kubelet journal shows failing probes against 6443. If `crictl logs` is empty because the
container was replaced, read the files under `/var/log/pods/…` instead — the kubelet keeps
the previous instance's log there.

**These are the only tools that work right now.** `kubectl` talks to the API server, and the
API server is down — so container-level tooling is all you have. That is the whole reason
`crictl` is on the exam.
