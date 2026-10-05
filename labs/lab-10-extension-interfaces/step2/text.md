# Step 2 — CNI: where the network plugin lives

```bash
ls /etc/cni/net.d/
ls /opt/cni/bin/
```

`/etc/cni/net.d/*.conflist` is the active CNI config. `/opt/cni/bin/` holds the plugin binaries. The kubelet calls these binaries every time a pod is created or deleted.

Look at the live CNI config — the file may be `.conflist` or `.conf` depending on the
plugin:

```bash
sudo cat /etc/cni/net.d/* 2>/dev/null | head -40
```

**Expected result:** one config naming your CNI (`calico`, `cilium` or `flannel`) and a
`/opt/cni/bin/` directory holding plugin binaries such as `bridge`, `host-local`, `loopback`
and your plugin's own binary.

> If `/etc/cni/net.d/` is empty, no CNI is installed — that is exactly why nodes sit
> `NotReady` after `kubeadm init` until Lab 3 installs one.
