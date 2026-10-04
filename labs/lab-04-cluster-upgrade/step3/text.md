# Step 3 — Plan and apply on the control plane

```bash
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply $(kubeadm version -o short) -y
```

`upgrade plan` prints what each component would move to and refuses unsupported jumps.
`upgrade apply` replaces the static pods in `/etc/kubernetes/manifests/` one at a time,
health-checking between each. On a 1-CPU node this takes several minutes.

If `upgrade plan` reports you are already on the latest version, there is nothing to
upgrade to: run `sudo kubeadm upgrade apply $(kubeadm version -o short) --dry-run` to see
what it would do, and read the "Already on the newest version?" section of `lab.md`.
