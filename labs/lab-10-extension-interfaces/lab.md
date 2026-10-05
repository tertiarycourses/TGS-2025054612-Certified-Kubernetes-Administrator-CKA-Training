# Lab 10 — Extension Interfaces (CNI, CSI, CRI)

Kubernetes plugs into the host via three standard interfaces:
- **CRI** — Container Runtime Interface (containerd, CRI-O)
- **CNI** — Container Network Interface (Calico, Cilium, Flannel)
- **CSI** — Container Storage Interface (AWS EBS, GCE PD, local-path, Ceph)

In this lab you inspect each one on a running cluster.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — CRI: talk to the runtime directly

`kubelet` talks to the runtime over a Unix socket. `crictl` is the debug client.

```bash
sudo crictl info | head -20
sudo crictl ps
sudo crictl images | head
```

Inspect the kubelet's runtime endpoint:

```bash
sudo grep -E "runtime|cgroup" /var/lib/kubelet/config.yaml
ls /etc/crictl.yaml /run/containerd/containerd.sock 2>/dev/null
```

**Expected result:** `crictl info` prints the runtime's JSON config, `crictl ps` lists the
control-plane containers, and the kubelet config shows `cgroupDriver: systemd` plus a
`containerRuntimeEndpoint`. The socket `/run/containerd/containerd.sock` exists.

> `crictl` talks to the **runtime**, not to Kubernetes — which is why it still works when
> the API server is down. That makes it the tool of choice for the troubleshooting labs.

---

## Step 2 — CNI: where the network plugin lives

```bash
ls /etc/cni/net.d/
ls /opt/cni/bin/
```

`/etc/cni/net.d/*.conflist` is the active CNI config. `/opt/cni/bin/` holds the plugin binaries. The kubelet calls these binaries every time a pod is created or deleted.

Look at the live CNI config — the file may be `.conflist` or `.conf` depending on the
plugin:

```bash
sudo cat /etc/cni/net.d/* 2>/dev/null | head -40
```

**Expected result:** one config naming your CNI (`calico`, `cilium` or `flannel`) and a
`/opt/cni/bin/` directory holding plugin binaries such as `bridge`, `host-local`, `loopback`
and your plugin's own binary.

> If `/etc/cni/net.d/` is empty, no CNI is installed — that is exactly why nodes sit
> `NotReady` after `kubeadm init` until Lab 3 installs one.

---

## Step 3 — CSI: list installed drivers

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

---

## Step 4 — Trace a pod through all three interfaces

```bash
kubectl run demo --image=nginx
kubectl wait --for=condition=Ready pod/demo --timeout=60s

# CRI side
sudo crictl ps | grep demo

# CNI side
kubectl get pod demo -o jsonpath='{.status.podIP}{"\n"}'

# CSI side - only exists if a driver is installed
kubectl describe csinode $(hostname) 2>/dev/null || echo "no csinode object (no CSI driver installed)"
```

**Expected result:** `crictl ps` shows the pod's container, the pod has an IP from the CNI's
pod CIDR, and the CSI lookup reports no driver — the three interfaces, in one pod's
lifecycle.

Tear down:

```bash
kubectl delete pod demo
```

---

## Step 5 — Read the CRI socket type from the kubelet config

```bash
sudo grep -E "containerRuntimeEndpoint|imageServiceEndpoint" /var/lib/kubelet/config.yaml
```

**Expected result:** `containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock`
(or `/run/containerd/...` — the same socket, `/var/run` is a symlink to `/run`). An empty
result means the kubelet is using its built-in default, which is the same path.

> `imageServiceEndpoint` is usually absent: since the CRI merge, the image service shares
> the runtime socket.

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — CRI | `crictl ps` lists containers; kubelet config shows `cgroupDriver: systemd` and a containerd endpoint |
| Step 2 — CNI | a config in `/etc/cni/net.d/` naming your plugin, and binaries in `/opt/cni/bin/` |
| Step 3 — CSI | `No resources found` for csidrivers/csinodes on a plain kubeadm cluster — expected |
| Step 4 — one pod, three interfaces | container visible in `crictl`, pod IP from the CNI, no CSI driver |
| Step 5 — kubelet endpoint | `unix:///var/run/containerd/containerd.sock` |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `crictl: command not found` | Use the full path or `sudo crictl`; it ships with the container runtime, not with kubectl. |
| `crictl` warns about an unset endpoint | Harmless, or set it once: `sudo crictl config runtime-endpoint unix:///run/containerd/containerd.sock`. |
| `/etc/cni/net.d/` is empty | No CNI installed — nodes will be `NotReady`. See Lab 3. |
| `kubectl get csidrivers` is empty | Correct on a plain kubeadm cluster. Nothing to fix. |
| `csinode "..." not found` | Same reason: csinode objects only appear once a CSI driver registers. |
| `permission denied` reading kubelet config | Prefix with `sudo` — `/var/lib/kubelet/config.yaml` is root-only. |

---

## What you learned
- Three standard plug-points: CRI, CNI, CSI.
- The on-disk locations and sockets that each interface uses.
- How to read the running configuration with `crictl`, `kubectl get csidrivers`, and the kubelet config file.
