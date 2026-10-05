# Step 3 — CSI: list installed drivers

```bash
kubectl get csidrivers
kubectl get csinodes
kubectl get storageclasses
```

**Expected result:** on a plain `kubeadm` cluster all three lists are usually **empty** —
`No resources found`. That is correct, not a fault: CSI drivers are add-ons, and this
cluster has none. Managed clusters (EKS, GKE) and k3s-style distributions ship one, so you
would see `ebs.csi.aws.com` or `rancher.io/local-path` there instead.

Each driver that *is* installed registers with the kubelet over a socket under
`/var/lib/kubelet/plugins/<driver>/csi.sock`:

```bash
sudo ls /var/lib/kubelet/plugins/ 2>/dev/null || echo "no CSI plugins registered"
sudo ls /var/lib/kubelet/plugins_registry/ 2>/dev/null || echo "no registry entries"
```

**Expected result:** empty or absent on this cluster. Labs 23-25 add storage and revisit
this.
