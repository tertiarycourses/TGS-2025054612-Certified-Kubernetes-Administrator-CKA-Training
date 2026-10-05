# Lab 26 — Troubleshoot Cluster Components

When the control plane misbehaves, you need to know which static pod, systemd service, or socket to inspect. In this lab you break the API server's static-pod manifest, observe the symptoms, and recover.

**Lab environment:** [two-node playground](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node) ·
**Prerequisite:** a working cluster (Labs 1-3)

> **You are about to break the API server on purpose.** Everything is recoverable with the
> `sed` in Step 4, but do not run this on a cluster anyone else is using.

---

## Step 1 — Map components to their on-disk source

```bash
sudo ls /etc/kubernetes/manifests/
```

Each YAML is a **static pod** the kubelet watches and runs:
- `kube-apiserver.yaml`
- `kube-controller-manager.yaml`
- `kube-scheduler.yaml`
- `etcd.yaml`

```bash
sudo systemctl status kubelet --no-pager | head
sudo systemctl status containerd --no-pager | head
```

**Expected result:** four manifests in `/etc/kubernetes/manifests/`, and both
`kubelet` and `containerd` reported `active (running)`.

The split matters when things break: the control plane runs as **static pods** the kubelet
starts from those files (no Deployment, no scheduler involved), while the kubelet and
containerd are **systemd services**. So a broken control-plane component is a file problem,
and a dead kubelet is a systemd problem.

---

## Step 2 — Break the API server

```bash
sudo sed -i 's|--secure-port=6443|--secure-port=6444|' /etc/kubernetes/manifests/kube-apiserver.yaml
```

Within ~20 s the kubelet re-creates the pod with the bad port.

Give the kubelet ~20 seconds to notice the changed file, then:

```bash
sleep 25
kubectl get nodes
```

**Expected result:** `The connection to the server … was refused`. The API server is now
listening on 6444 while every kubeconfig and its own liveness probe still use 6443, so the
kubelet keeps restarting it.

> This is the most realistic control-plane failure there is: a one-character edit in a
> static-pod manifest, and the cluster is unreachable.

---

## Step 3 — Diagnose

The API is gone, so use container-level tools.

> **`crictl: command not found`?** It is not part of containerd or kubeadm — the playground
> image often lacks it. Install it from the same Kubernetes apt repo (see Lab 1, Step 6), or
> use containerd's own CLI, which is always present:
>
> ```bash
> command -v crictl || sudo apt-get install -y cri-tools
> # or, with no install at all:
> sudo ctr -n k8s.io containers ls | head
> ```


```bash
sudo crictl ps -a | grep apiserver
sudo crictl logs $(sudo crictl ps -a | grep apiserver | awk '{print $1}' | head -1) 2>&1 | tail -20
sudo journalctl -u kubelet --no-pager | tail -30
sudo ls /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/
```

**Expected result:** `crictl ps -a` lists the apiserver container repeatedly `Exited`, and
the kubelet journal shows failing probes against 6443. If `crictl logs` is empty because the
container was replaced, read the files under `/var/log/pods/…` instead — the kubelet keeps
the previous instance's log there.

**These are the only tools that work right now.** `kubectl` talks to the API server, and the
API server is down — so container-level tooling is all you have. That is the whole reason
`crictl` is on the exam.

---

## Step 4 — Fix

```bash
sudo sed -i 's|--secure-port=6444|--secure-port=6443|' /etc/kubernetes/manifests/kube-apiserver.yaml
```

The kubelet re-reads the manifest within ~20 seconds and recreates the pod, so wait for
the API rather than guessing:

```bash
until kubectl get --raw=/readyz > /dev/null 2>&1; do echo "waiting for the API..."; sleep 5; done
kubectl get nodes
kubectl -n kube-system get pods -l component=kube-apiserver
```

**Expected result:** the API answers again, both nodes are `Ready`, and the apiserver pod is
`Running` with a non-zero `RESTARTS` count — evidence of what you just did. Recovery needs
no `systemctl` and no `kubectl`: fixing the file is enough, because the kubelet is watching
it.

---

## Step 5 — etcd health

```bash
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health
```

**Expected result:**

```text
https://127.0.0.1:2379 is healthy: successfully committed proposal: took = 12ms
```

Anything else — a timeout, a certificate error — means etcd itself is the problem, and no
amount of apiserver debugging will help. Check the member list and sizes too:

```bash
sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint status --write-out=table
```

**Expected result:** one row: this member, its DB size, and `RAFT TERM`. A DB approaching
the 2 GB default quota is a real-world outage waiting to happen.

---

## Step 6 — Controller-manager and scheduler

```bash
kubectl -n kube-system logs $(kubectl -n kube-system get pod -l component=kube-controller-manager -o name) | tail
kubectl -n kube-system logs $(kubectl -n kube-system get pod -l component=kube-scheduler -o name) | tail
```

**Expected result:** recent log lines from both components. Right after Step 4 you will
very likely see `leaderelection lost` or `connection refused` entries — they lost their lease
while the API server was down, which is exactly the fingerprint of a control-plane outage in
someone else's logs.

```bash
kubectl -n kube-system get pods -l tier=control-plane -o wide
```

**Expected result:** `etcd`, `kube-apiserver`, `kube-controller-manager` and
`kube-scheduler` all `Running` on the control-plane node.

---

## Step 7 — Cheat sheet

| Symptom                              | Look at                                                      |
|--------------------------------------|--------------------------------------------------------------|
| `kubectl` hangs / `connection refused`| `/var/log/pods/kube-system_kube-apiserver-*`, `crictl logs` |
| Nodes stuck `NotReady`               | `journalctl -u kubelet`, `journalctl -u containerd`          |
| Pods stuck `Pending`                 | kube-scheduler logs                                          |
| New ReplicaSet not creating pods     | kube-controller-manager logs                                 |
| Persistent data missing / inconsistent | etcd logs + `etcdctl endpoint status --write-out=table`     |

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — mapping | four static-pod manifests; kubelet and containerd `active` |
| Step 2 — broken | `connection refused` from kubectl |
| Step 3 — diagnosis | apiserver container `Exited`; kubelet journal shows failing probes |
| Step 4 — recovered | `/readyz` answers, nodes `Ready`, apiserver `RESTARTS` > 0 |
| Step 5 — etcd | `is healthy: successfully committed proposal`, one member in the status table |
| Step 6 — other components | controller-manager and scheduler Running, with leader-election churn logged |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `kubectl` never comes back after Step 4 | Re-check the manifest: `sudo grep secure-port /etc/kubernetes/manifests/kube-apiserver.yaml` must read 6443. |
| `crictl logs` prints nothing | The container was replaced. Read `/var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/*.log`. |
| `crictl: command not found` | Use `sudo crictl`; it ships with containerd, not kubectl. |
| etcd health check times out | etcd is down or the certificate paths are wrong — read them from `/etc/kubernetes/manifests/etcd.yaml`. |
| Static pod does not restart | The kubelet is down: `sudo systemctl status kubelet` and `journalctl -u kubelet -n 50`. |
| YAML indentation error in the manifest | The kubelet logs `failed to parse`. Compare against a backup, or regenerate with `kubeadm init phase control-plane apiserver`. |

---

## What you learned
- Static-pod manifest path: `/etc/kubernetes/manifests/`.
- Use `crictl` and `journalctl` when `kubectl` is unavailable.
- The control-plane → on-disk → log mapping for fast triage.
