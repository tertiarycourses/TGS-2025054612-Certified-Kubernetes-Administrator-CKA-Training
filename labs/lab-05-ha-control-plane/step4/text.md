# Step 4 — Take and verify the snapshot

```bash
sudo ETCDCTL_API=3 etcdctl --endpoints=$EP --cacert=$CA --cert=$CERT --key=$KEY \
  snapshot save /opt/etcd-backup.db
ls -lh /opt/etcd-backup.db
```

**Expected result:** `Snapshot saved at /opt/etcd-backup.db`, a file of a few tens of MB.

Verify it — a snapshot you have not inspected is not a backup:

```bash
if command -v etcdutl > /dev/null; then
  sudo etcdutl --write-out=table snapshot status /opt/etcd-backup.db
else
  sudo ETCDCTL_API=3 etcdctl --write-out=table snapshot status /opt/etcd-backup.db
fi
```

**Expected result:** a table with HASH, REVISION, TOTAL KEYS and TOTAL SIZE. Thousands of
keys is normal.

> **`etcdctl` or `etcdutl`?** Snapshot *save* talks to a running etcd, so it is always
> `etcdctl`. Snapshot *status* and *restore* only touch files, and etcd 3.5 moved them to
> `etcdutl`; etcd 3.6 removed `restore` from `etcdctl` altogether. The `if` above works
> either way — in the exam, check with `command -v etcdutl` before you type.
