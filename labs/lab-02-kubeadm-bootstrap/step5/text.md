# Step 5 — Explore what kubeadm built

```bash
ls /etc/kubernetes/
ls /etc/kubernetes/manifests/
ls /etc/kubernetes/pki/
```

- `manifests/*.yaml` — static pod definitions watched by kubelet.
- `pki/` — the CA, API server, etcd, and service-account keys.
- `admin.conf`, `controller-manager.conf`, `scheduler.conf`, `kubelet.conf` — kubeconfigs for each component.

**Expected result:** `manifests/` holds the four static-pod YAMLs, `pki/` holds `ca.crt`,
`apiserver.crt`, the `etcd/` sub-directory and `sa.key`, and the four kubeconfigs sit in
`/etc/kubernetes/`.

Worth remembering for the troubleshooting labs: **everything the control plane needs is
these files**. Lab 26 breaks one on purpose, and Lab 5 backs up the data behind them.
