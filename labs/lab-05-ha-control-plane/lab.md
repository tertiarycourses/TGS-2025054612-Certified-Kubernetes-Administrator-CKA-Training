# Lab 5 — HA Control Plane Overview and etcd Backup/Restore

A real HA control plane needs three machines with 2 CPUs each; this environment gives you
two 1-CPU nodes, so HA is covered here as a **high-level overview** you can reason about
in the exam. The hands-on half is the thing a CKA actually gets asked to do on a single
control plane: **back up etcd and restore it**, losing nothing.

**Lab environment:** [two-node playground](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node) ·
**Prerequisite:** a working cluster (`kubectl get nodes` responds)

> If `kubectl` answers with `localhost:8080 ... connection refused`, it has no kubeconfig —
> copy it first:
> ```bash
> mkdir -p $HOME/.kube
> sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
> sudo chown $(id -u):$(id -g) $HOME/.kube/config
> ```

---

## What you must be able to show

| Outcome | How you prove it |
|---|---|
| You can explain HA and quorum | the topology and quorum table in Step 1 |
| You can tell whether a cluster is HA-ready | `controlPlaneEndpoint` present or absent in `kubeadm-config` |
| You can find etcd's endpoint and certificates | read them out of `/etc/kubernetes/manifests/etcd.yaml` |
| You can take a verified snapshot | `snapshot save`, then `snapshot status` showing revision and size |
| You can restore it | deleted Deployment, Service and ConfigMap all return after the restore |

---

## Part 1 — HA control plane: the overview

### Step 1 — Topology, quorum, and what makes a cluster HA-ready

The standard layout is **stacked etcd**: every control-plane node runs an apiserver *and*
an etcd member, behind one load-balanced address.

```
                      clients: kubectl, kubelets
                                  │
                        VIP / load balancer :6443
                                  │
            ┌─────────────────────┼─────────────────────┐
            ▼                     ▼                     ▼
          cp-1                  cp-2                  cp-3     ← apiserver + etcd member
            │                     │                     │
            └─────────────────────┼─────────────────────┘
                                  ▼
                               workers
```

| etcd members | Quorum | Failures tolerated |
|---|---|---|
| 1 | 1 | 0 |
| 2 | 2 | 0 |
| 3 | 2 | 1 |
| 5 | 3 | 2 |

Quorum is `(n/2)+1`. Two members tolerate **nothing** — which is why control planes
come in odd numbers. Lose quorum and etcd goes read-only: running pods keep running,
but no change is accepted.

Three things make a cluster HA-ready, and only the first must be decided at bootstrap:

| Piece | Why | Command |
|---|---|---|
| A shared endpoint | baked into certificates and kubeconfigs, so clients and new control planes use the LB, not one node's IP | `kubeadm init --control-plane-endpoint "k8s-vip:6443"` |
| Uploaded certificates | lets control plane #2 and #3 join without copying PKI by hand | `--upload-certs`, then `kubeadm join … --control-plane --certificate-key <key>` |
| A TCP load balancer | passes 6443 through to each apiserver; HAProxy + keepalived for the floating IP | `frontend … bind *:6443`, `mode tcp` |

Check where your own cluster stands:

```bash
kubectl get nodes -l node-role.kubernetes.io/control-plane
kubectl -n kube-system get cm kubeadm-config -o yaml | grep -i controlPlaneEndpoint || \
  echo "no controlPlaneEndpoint: this cluster cannot gain more control planes without reissuing certs"
```

**Expected result:** one control-plane node. Whether `controlPlaneEndpoint` appears depends
on how you bootstrapped: `kubeadm init` without `--control-plane-endpoint` bakes in the
node's own IP, and adding a load balancer later means reissuing certificates. That is the
single most important HA decision, and it is made in the first command you run.

> **Why we stop here:** a second control plane needs its own VM with 2 CPUs. Adding one on
> this playground fails on resources, not on your understanding. The rest of the lab spends
> its time on something you *can* complete end to end — and that the exam weights heavily.

---

## Part 2 — etcd backup and restore (hands-on)

etcd holds **all** cluster state: every namespace, Deployment, Secret and RBAC rule. Losing
it loses the cluster; a snapshot plus the restore procedure gets it back.

### Step 2 — Find etcd's endpoint, certificates and data directory

Never guess these — they are in the static-pod manifest that defines etcd:

```bash
sudo grep -E "data-dir|listen-client-urls|--cert-file|--key-file|trusted-ca-file" \
  /etc/kubernetes/manifests/etcd.yaml
sudo grep -A3 "name: etcd-data" /etc/kubernetes/manifests/etcd.yaml
```

**Expected result:** client URL `https://127.0.0.1:2379`, server cert and key under
`/etc/kubernetes/pki/etcd/`, `--data-dir=/var/lib/etcd` inside the container, and a
`hostPath` of `/var/lib/etcd` on the node.

Install the client tools on the node — the restore must run on the host, while etcd is
stopped, so an exec into the pod will not do:

```bash
sudo apt-get update -qq && sudo apt-get install -y etcd-client
etcdctl version
```

If that package is unavailable, or `etcdutl` is missing from it, take both binaries
straight from an official etcd release:

```bash
ETCD_VER=v3.5.21
curl -sL "https://github.com/etcd-io/etcd/releases/download/$ETCD_VER/etcd-$ETCD_VER-linux-amd64.tar.gz" \
  -o /tmp/etcd.tar.gz
sudo tar xzf /tmp/etcd.tar.gz -C /usr/local/bin --strip-components=1 \
  "etcd-$ETCD_VER-linux-amd64/etcdctl" "etcd-$ETCD_VER-linux-amd64/etcdutl"
etcdctl version && etcdutl version
```

Set the connection details once, so every command below is short:

```bash
export ETCDCTL_API=3
CA=/etc/kubernetes/pki/etcd/ca.crt
CERT=/etc/kubernetes/pki/etcd/server.crt
KEY=/etc/kubernetes/pki/etcd/server.key
EP=https://127.0.0.1:2379
```

Confirm you can reach etcd:

```bash
sudo ETCDCTL_API=3 etcdctl --endpoints=$EP --cacert=$CA --cert=$CERT --key=$KEY \
  endpoint health
```

**Expected result:** `https://127.0.0.1:2379 is healthy`. If you get a certificate error,
re-read the paths from the manifest above — wrong flags are the most common exam mistake.

---

### Step 3 — Create the state you are going to lose

A backup proves nothing unless something recognisable disappears and comes back.

```bash
kubectl create namespace demo-backup
kubectl -n demo-backup create deployment web --image=nginx:1.27-alpine --replicas=2
kubectl -n demo-backup expose deployment web --port=80
kubectl -n demo-backup create configmap app-config --from-literal=owner=mohan
kubectl -n demo-backup get deploy,svc,cm
```

**Expected result:** Deployment `web`, Service `web` and ConfigMap `app-config` all listed.

> Pods may sit `Pending` if this cluster has no CNI yet (see Lab 3) — that is fine. The
> restore is proven by the **objects** returning, not by pods running.

---

### Step 4 — Take and verify the snapshot

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

---

### Step 5 — Lose the data

```bash
kubectl delete namespace demo-backup
kubectl get ns | grep demo-backup || echo "demo-backup is gone"
```

**Expected result:** `demo-backup is gone`. Everything you created in Step 3 no longer
exists in etcd.

---

### Step 6 — Restore, and get it all back

The control plane must not be running while etcd's data directory is replaced. Static pods
are started by the kubelet from `/etc/kubernetes/manifests`, so moving the manifests aside
stops them.

**1. Stop the control plane:**

```bash
sudo mkdir -p /etc/kubernetes/manifests-stopped
sudo mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
until ! sudo crictl ps 2>/dev/null | grep -q etcd; do sleep 3; done
echo "control plane stopped"
```

`kubectl` stops answering now — expected, the apiserver is down.

**2. Restore the snapshot into a NEW data directory.** Never restore over a directory that
still has data; etcd refuses, and a half-replaced directory is worse than no backup:

```bash
if command -v etcdutl > /dev/null; then
  sudo etcdutl snapshot restore /opt/etcd-backup.db --data-dir=/var/lib/etcd-restore
else
  sudo ETCDCTL_API=3 etcdctl snapshot restore /opt/etcd-backup.db --data-dir=/var/lib/etcd-restore
fi
sudo ls /var/lib/etcd-restore/member
```

**Expected result:** a `member/` directory containing `snap` and `wal`.

**3. Point etcd at the restored directory.** Only the node-side `hostPath` changes; the
container still sees `/var/lib/etcd`:

```bash
sudo sed -i 's#path: /var/lib/etcd$#path: /var/lib/etcd-restore#' \
  /etc/kubernetes/manifests-stopped/etcd.yaml
sudo grep -A3 "name: etcd-data" /etc/kubernetes/manifests-stopped/etcd.yaml
```

**Expected result:** the `hostPath` now reads `/var/lib/etcd-restore`.

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
```

**Expected result:** the namespace is back, with Deployment `web`, Service `web` and
ConfigMap `app-config` — the exact state captured in Step 4. The cluster has been rewound
to the moment of the snapshot.

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — HA readiness | one control-plane node; you can say whether `controlPlaneEndpoint` is set and why it matters |
| Step 2 — etcd reachable | `https://127.0.0.1:2379 is healthy` |
| Step 3 — state created | Deployment, Service and ConfigMap in `demo-backup` |
| Step 4 — snapshot verified | `Snapshot saved`, and a status table with REVISION and TOTAL KEYS |
| Step 5 — state lost | `demo-backup is gone` |
| Step 6 — state restored | `demo-backup` and all three objects are listed again |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `context deadline exceeded` on `snapshot save` | Wrong endpoint or certificates. Re-read them from `/etc/kubernetes/manifests/etcd.yaml` (Step 2). |
| `etcdctl: command not found` | `sudo apt-get install -y etcd-client`, or install both binaries from the release tarball as shown in Step 2. |
| `unknown command "restore"` | etcd 3.6 removed restore from `etcdctl`: use `etcdutl snapshot restore`. |
| `data-dir "/var/lib/etcd-restore" exists` | Restore target must be new: `sudo rm -rf /var/lib/etcd-restore` and retry. |
| `kubectl` still refused long after Step 6 | Check the static pods came back: `ls /etc/kubernetes/manifests`, then `sudo crictl ps -a \| grep etcd` and `sudo journalctl -u kubelet -n 50`. |
| Objects still missing after restore | etcd is probably still on the old directory. Confirm the `hostPath` edit, then restart the pod by moving `etcd.yaml` out and back. |
| `localhost:8080 ... refused` | No kubeconfig — copy `admin.conf` as shown at the top. |

## Exam tips

- `snapshot save` needs `--endpoints`, `--cacert`, `--cert`, `--key`. Forgetting one is the
  most common lost mark.
- Restore to a **new** `--data-dir`, then repoint the `hostPath`. Do not try to restore in
  place.
- Moving manifests out of `/etc/kubernetes/manifests` is the fastest way to stop and start
  the control plane. Remember to move them **back**.
- `ETCDCTL_API=3` is the default from etcd 3.4 onwards, but setting it explicitly costs
  nothing and saves you on older clusters.

---

## What you learned
- The stacked-etcd topology, quorum arithmetic, and why control planes come in odd numbers.
- That `--control-plane-endpoint` and `--upload-certs` decide at bootstrap whether a cluster
  can ever gain more control planes.
- Where etcd's endpoint, certificates and data directory are declared, and how to read them
  from the static-pod manifest.
- How to take and **verify** an etcd snapshot.
- The full restore procedure: stop the control plane, restore to a new data directory,
  repoint the `hostPath`, restart, and confirm the recovered objects.
