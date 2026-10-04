# Step 6 — Restore, and get it all back

**1. Stop the control plane** — the kubelet runs these pods from the manifest directory, so
moving the files aside stops them:

```bash
sudo mkdir -p /etc/kubernetes/manifests-stopped
sudo mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
until ! sudo crictl ps 2>/dev/null | grep -q etcd; do sleep 3; done
echo "control plane stopped"
```

`kubectl` stops answering now — the apiserver is down.

**2. Restore into a NEW data directory** (etcd refuses a directory that still has data):

```bash
if command -v etcdutl > /dev/null; then
  sudo etcdutl snapshot restore /opt/etcd-backup.db --data-dir=/var/lib/etcd-restore
else
  sudo ETCDCTL_API=3 etcdctl snapshot restore /opt/etcd-backup.db --data-dir=/var/lib/etcd-restore
fi
sudo ls /var/lib/etcd-restore/member
```

**3. Point etcd at it** — only the node-side `hostPath` changes:

```bash
sudo sed -i 's#path: /var/lib/etcd$#path: /var/lib/etcd-restore#' \
  /etc/kubernetes/manifests-stopped/etcd.yaml
sudo grep -A3 "name: etcd-data" /etc/kubernetes/manifests-stopped/etcd.yaml
```

**4. Start the control plane and wait:**

```bash
sudo mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
until kubectl get --raw=/readyz > /dev/null 2>&1; do sleep 5; done
echo "API server is back"
```

**5. Prove it:**

```bash
kubectl get ns demo-backup
kubectl -n demo-backup get deploy,svc,cm
```

The namespace, Deployment, Service and ConfigMap are all back — the cluster has been
rewound to the snapshot.
