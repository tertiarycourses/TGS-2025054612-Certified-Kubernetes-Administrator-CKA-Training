# Step 3 — Plan and apply on the control plane

```bash
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply $(kubeadm version -o short) -y
```

**Expected result:** `upgrade plan` prints a table of current versus target version for
each component, and `upgrade apply` ends with
`SUCCESS! Your cluster was upgraded to "vX.Y.Z". Enjoy!`.

`upgrade plan` refuses an unsupported jump before anything changes. `upgrade apply` then replaces the static pods in
`/etc/kubernetes/manifests/` one at a time, health-checking between each. On a 1-CPU
playground node this takes several minutes; slow `[upgrade/health]` waits are normal.
