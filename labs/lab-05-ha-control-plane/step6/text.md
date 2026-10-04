# Step 6 — Restore, and get it all back

The order below matters: the snapshot is restored into a new directory **first**, while
the cluster is still running, because `snapshot restore` only writes files and needs no
running etcd. The control plane is then stopped for the shortest possible time.

**1. Restore the snapshot into a NEW data directory.** Never restore over a directory that
still holds data — etcd refuses, and a half-replaced directory is worse than no backup:

```bash
if command -v etcdutl > /dev/null; then
  sudo etcdutl snapshot restore /opt/etcd-backup.db --data-dir=/var/lib/etcd-restore
else
  sudo ETCDCTL_API=3 etcdctl snapshot restore /opt/etcd-backup.db --data-dir=/var/lib/etcd-restore
fi
sudo ls /var/lib/etcd-restore/member
```

**Expected result:** `snap  wal`.

> ### Do not continue until that directory exists
> This is the step everything else depends on. If you skip it, the `hostPath` you set in
> step 3 points at a directory that does not exist — and because the manifest says
> `type: DirectoryOrCreate`, the kubelet **creates it empty**. etcd then starts as a brand
> new, blank cluster: no namespaces, no workloads, and no RBAC, which shows up as
> `Error from server (Forbidden): … User "kubernetes-admin" cannot …` on every command.
> Nothing is lost if that happens — your snapshot is still on disk. Stop the control plane,
> `sudo rm -rf /var/lib/etcd-restore`, run the restore above for real, and start again.

**2. Stop the control plane.** Static pods are started by the kubelet from
`/etc/kubernetes/manifests`, so moving the manifests aside stops them:

```bash
sudo mkdir -p /etc/kubernetes/manifests-stopped
sudo mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
until ! sudo crictl ps 2>/dev/null | grep -q etcd; do sleep 3; done
echo "control plane stopped"
```

`kubectl` stops answering now — expected, the apiserver is down.

**3. Point etcd at the restored directory.** Only the node-side `hostPath` changes; the
container still sees `/var/lib/etcd`:

```bash
sudo sed -i 's#path: /var/lib/etcd$#path: /var/lib/etcd-restore#' \
  /etc/kubernetes/manifests-stopped/etcd.yaml
sudo grep -n "path: /var/lib/etcd" /etc/kubernetes/manifests-stopped/etcd.yaml
```

**Expected result:** one line, reading `path: /var/lib/etcd-restore`. If it still says
`/var/lib/etcd`, the edit did not land and the restore will have no effect.

> Grep for the `path:` line itself, not for `name: etcd-data` — in this manifest the path
> sits *above* the volume name, so `grep -A3 "name: etcd-data"` would show you the wrong
> lines and tell you nothing.

**4. Start the control plane again and wait for the API:**

```bash
sudo mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
until kubectl get --raw=/readyz > /dev/null 2>&1; do sleep 5; done
echo "API server is back"
```

On a 1-CPU node this takes a minute or two while etcd replays and the apiserver restarts.

**5. Prove the restore worked:**

```bash
kubectl get ns demo-backup
kubectl -n demo-backup get deploy,svc,cm
kubectl -n demo-backup get pods
```

**Expected result:** the namespace is back with Deployment `web`, Service `web` and
ConfigMap `app-config` — the exact state captured in Step 4 — and the pods are recreated by
the Deployment. The cluster has been rewound to the moment of the snapshot.
