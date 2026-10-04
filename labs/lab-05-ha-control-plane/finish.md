# Well done!

You have completed Lab 5 — HA Control Plane Overview and etcd Backup/Restore:

✅ Explained the stacked-etcd topology, quorum `(n/2)+1`, and why control planes come in
   odd numbers
✅ Checked whether your cluster is HA-ready by looking for `controlPlaneEndpoint`
✅ Read etcd's endpoint, certificates and data directory from
   `/etc/kubernetes/manifests/etcd.yaml`
✅ Took a snapshot with `etcdctl snapshot save` and verified it with `snapshot status`
✅ Deleted the `demo-backup` namespace, then restored etcd into a new data directory,
   repointed the `hostPath`, and restarted the control plane
✅ Confirmed the Deployment, Service and ConfigMap all came back

**Next:** Lab 6 — Install Components with Helm
