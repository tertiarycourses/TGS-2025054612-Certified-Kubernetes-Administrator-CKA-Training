# Step 6 — Verify

```bash
kubeadm version
kubectl version --client
sudo systemctl status containerd --no-pager | head
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock version
```

You should see the `kubeadm` version you noted in Step 0 (for example `v1.37.1`), `containerd` active, and `crictl` reporting the runtime version.

---

> ✅ **Test it:** Both tabs show `kubeadm version` returning the version you noted in Step 0, `containerd` is active, and `kubectl version --client` works — the nodes are ready for `kubeadm init` in Lab 2.
