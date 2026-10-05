# Step 5 — Read the CRI socket type from the kubelet config

```bash
sudo grep -E "containerRuntimeEndpoint|imageServiceEndpoint" /var/lib/kubelet/config.yaml
```

**Expected result:** `containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock`
(or `/run/containerd/...` — the same socket, `/var/run` is a symlink to `/run`). An empty
result means the kubelet is using its built-in default, which is the same path.

> `imageServiceEndpoint` is usually absent: since the CRI merge, the image service shares
> the runtime socket.
