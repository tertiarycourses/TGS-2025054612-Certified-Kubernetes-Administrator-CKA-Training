# Step 6 — Restore, and get it all back

A restore is four phases that must happen **in order, with nothing in between**:

| # | Phase | Why |
|---|---|---|
| 1 | Restore the snapshot into a **new** directory | `snapshot restore` only writes files, so it needs no running etcd — do it first and the cluster is down for less time |
| 2 | Stop the control plane | the kubelet runs the control plane from `/etc/kubernetes/manifests`; moving the files aside stops it, and etcd must not be running while its data directory is swapped |
| 3 | Point etcd's `hostPath` at the restored directory | the container keeps seeing `/var/lib/etcd`; only the node-side path changes |
| 4 | Put the manifests back and wait for the API | the kubelet starts the control plane again, now on the restored data |

**Paste this whole block.** It runs all four phases and prints progress — stopping halfway
is what breaks a restore (see the warnings below):

```bash
set -e
SNAP=/opt/etcd-backup.db
NEW=/var/lib/etcd-restore

# Phase 1 - restore into a new data directory
sudo rm -rf "$NEW"
if command -v etcdutl > /dev/null; then
  sudo etcdutl snapshot restore "$SNAP" --data-dir="$NEW"
else
  sudo ETCDCTL_API=3 etcdctl snapshot restore "$SNAP" --data-dir="$NEW"
fi
sudo ls "$NEW/member"                      # must print: snap  wal
echo "--- phase 1 done: snapshot restored"

# Phase 2 - stop the control plane
sudo mkdir -p /etc/kubernetes/manifests-stopped
sudo mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
# Wait until etcd's client port is closed. Do NOT test this with `crictl ps | grep etcd`:
# if crictl is missing, that prints nothing, the grep fails, and the loop exits instantly -
# the restore would then run while etcd is still writing.
until ! sudo ss -lnt 2>/dev/null | grep -q ':2379'; do sleep 3; done
echo "--- phase 2 done: control plane stopped (kubectl will not answer now)"

# Phase 3 - point etcd at the restored directory
sudo sed -i "s#path: /var/lib/etcd\$#path: $NEW#" \
  /etc/kubernetes/manifests-stopped/etcd.yaml
sudo grep -n "path: /var/lib/etcd" /etc/kubernetes/manifests-stopped/etcd.yaml
echo "--- phase 3 done: hostPath repointed"

# Phase 4 - start the control plane and wait for the API
sudo mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
until kubectl get --raw=/readyz > /dev/null 2>&1; do sleep 5; done
echo "--- phase 4 done: API server is back"
```

**Expected result:** `snap  wal`, then the four `phase … done` lines, with phase 3 printing
one line reading `path: /var/lib/etcd-restore`. On a 1-CPU node phase 4 takes a minute or
two while etcd replays and the apiserver restarts.

> ### If you stop halfway
> Both of these leave a cluster that looks broken but is fully recoverable — your snapshot
> is still on disk, so just run the block again from the top:
>
> | Stopped after | What you see | Why |
> |---|---|---|
> | phase 2 or 3 | `The connection to the server …:6443 was refused` on every command | the control plane is still stopped: its manifests are in `/etc/kubernetes/manifests-stopped/`. Finish phase 4. |
> | phase 2–4 without phase 1 | `Error from server (Forbidden): User "kubernetes-admin" cannot …` | the data directory did not exist, and `type: DirectoryOrCreate` made the kubelet create it **empty**, so etcd came up blank — RBAC included. |

Now prove the restore worked:

```bash
kubectl get ns demo-backup
kubectl -n demo-backup get deploy,svc,cm
kubectl -n demo-backup get pods
```

**Expected result:** the namespace is back with Deployment `web`, Service `web` and
ConfigMap `app-config` — the exact state captured in Step 4 — and the Deployment recreates
its pods. The cluster has been rewound to the moment of the snapshot.

<details>
<summary>Prefer to run the phases one at a time?</summary>

```bash
# 1. restore (cluster still running)
sudo rm -rf /var/lib/etcd-restore
sudo etcdutl snapshot restore /opt/etcd-backup.db --data-dir=/var/lib/etcd-restore \
  || sudo ETCDCTL_API=3 etcdctl snapshot restore /opt/etcd-backup.db --data-dir=/var/lib/etcd-restore
sudo ls /var/lib/etcd-restore/member

# 2. stop the control plane
sudo mkdir -p /etc/kubernetes/manifests-stopped
sudo mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
until ! sudo ss -lnt 2>/dev/null | grep -q ':2379'; do sleep 3; done

# 3. repoint the hostPath
sudo sed -i 's#path: /var/lib/etcd$#path: /var/lib/etcd-restore#' \
  /etc/kubernetes/manifests-stopped/etcd.yaml
sudo grep -n "path: /var/lib/etcd" /etc/kubernetes/manifests-stopped/etcd.yaml

# 4. start it again - DO NOT SKIP THIS
sudo mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
until kubectl get --raw=/readyz > /dev/null 2>&1; do sleep 5; done
echo "API server is back"
```

Grep for the `path:` line itself, not for `name: etcd-data` — in this manifest the path sits
*above* the volume name, so `grep -A3 "name: etcd-data"` shows the wrong lines.

</details>
