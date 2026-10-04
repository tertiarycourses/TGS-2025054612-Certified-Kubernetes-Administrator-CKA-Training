# Step 4 — Take and verify the snapshot

```bash
sudo ETCDCTL_API=3 etcdctl --endpoints=$EP --cacert=$CA --cert=$CERT --key=$KEY \
  snapshot save /opt/etcd-backup.db
ls -lh /opt/etcd-backup.db
```

Verify it — a snapshot you have not inspected is not a backup:

```bash
if command -v etcdutl > /dev/null; then
  sudo etcdutl --write-out=table snapshot status /opt/etcd-backup.db
else
  sudo ETCDCTL_API=3 etcdctl --write-out=table snapshot status /opt/etcd-backup.db
fi
```

A table with HASH, REVISION, TOTAL KEYS and TOTAL SIZE.

Snapshot *save* talks to a running etcd, so it is always `etcdctl`. *Status* and *restore*
only touch files: etcd 3.5 moved them to `etcdutl`, and 3.6 removed `restore` from
`etcdctl`.
