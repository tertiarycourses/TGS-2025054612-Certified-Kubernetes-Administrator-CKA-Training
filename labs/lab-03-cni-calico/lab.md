# Lab 3 — Install a CNI Plugin (Calico)

A fresh kubeadm cluster has no pod network. In this lab you install Calico, watch the nodes flip from `NotReady` to `Ready`, and verify pod-to-pod connectivity across nodes.

Continue on the **kubeadm playground** from Lab 2.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)

---

## Step 1 — Check for an existing CNI, then apply Calico

**Check first.** Two CNIs on one cluster fight over `/etc/cni/net.d` and pod IP allocation,
and the result is pods that never get an address. The shared playground image often ships
with one already running:

```bash
kubectl get pods -n kube-system -o wide | grep -Ei 'calico|cilium|flannel|weave' || \
  echo "no CNI installed - continue with Step 1"
ls /etc/cni/net.d/
```

**Expected result:** after a clean `kubeadm init` (Lab 2), no CNI pods and an empty or
nearly empty `/etc/cni/net.d/`. Then continue.

**If a CNI is already running** — for example `cilium-*` pods — you have two choices: skip
to Step 3 and verify connectivity with what is already installed (the lesson still holds),
or remove it first (`kubectl delete -f <its manifest>`, then
`sudo rm -f /etc/cni/net.d/*`) before installing Calico. Do **not** apply Calico on top.

On the **controlplane**:

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/calico.yaml
```

**Expected result:** a long list of `created` lines — CRDs, a ServiceAccount, RBAC, a
ConfigMap, a DaemonSet and a Deployment.

This single manifest ("Calico the hard way", no operator) creates everything in
**`kube-system`**:

- a DaemonSet `calico-node` — one pod per node, which installs the CNI binary into
  `/opt/cni/bin` and writes `/etc/cni/net.d/10-calico.conflist`;
- a Deployment `calico-kube-controllers` — the control loop for Calico's own resources;
- the `crd.projectcalico.org` CRDs that back IP pools and policy.

> The alternative install path is the **Tigera operator** (`tigera-operator.yaml` plus an
> `Installation` resource), which instead creates the `calico-system` and
> `calico-apiserver` namespaces. Practicum 1 uses that one; this lab uses the direct
> manifest because it is one command and easier to inspect.
>
> Calico reads the pod CIDR from the cluster, so the `192.168.0.0/16` you passed to
> `kubeadm init` in Lab 2 is picked up automatically — which is also why that value matters
> there.

---

## Step 2 — Watch pods come up

```bash
kubectl get pods -n kube-system -w
```

Rather than watching, wait for it:

```bash
kubectl -n kube-system rollout status ds/calico-node --timeout=300s
kubectl -n kube-system get pods -l k8s-app=calico-node -o wide
kubectl get nodes
```

**Expected result:** `calico-node` shows `2 of 2 updated and available`, one pod per node
with `1/1` ready, and **both nodes `Ready`**.

On a 1-CPU node this takes a few minutes: each `calico-node` pod runs init containers that
install the CNI plugin before the main container starts. CoreDNS, stuck `Pending` since
Lab 2, now gets an IP and starts:

```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns
```

**Expected result:** both CoreDNS pods `Running` — the clearest signal that the pod network
is live.

---

## Step 3 — Verify pod networking across nodes

Schedule two pods, one on each node:

```bash
kubectl run pod-a --image=nicolaka/netshoot --overrides='{"spec":{"nodeName":"controlplane"}}' --command -- sleep 3600
kubectl run pod-b --image=nicolaka/netshoot --overrides='{"spec":{"nodeName":"node01"}}'     --command -- sleep 3600
kubectl wait --for=condition=Ready pod/pod-a pod/pod-b --timeout=120s
kubectl get pods -o wide
```

**Expected result:** both pods `Running`, on **different** nodes, each with an IP from
`192.168.0.0/16`.

> Note the trick: `nodeName` in the overrides bypasses the scheduler entirely, so `pod-a`
> lands on the control plane **despite** its `NoSchedule` taint — taints are enforced when
> scheduling, and this pod was never scheduled.

Ping pod-b from pod-a:

```bash
POD_B_IP=$(kubectl get pod pod-b -o jsonpath='{.status.podIP}')
kubectl exec pod-a -- ping -c 3 $POD_B_IP
```

**Expected result:** `3 packets transmitted, 3 received, 0% packet loss`.

That is cross-node pod traffic: the packet left one node, crossed Calico's overlay
(IP-in-IP or VXLAN depending on the detected environment) and arrived at a pod on the other
node — with no NAT and no port mapping. If this fails while both pods are `Running`, the
overlay is the problem, not Kubernetes.

---

## Step 4 — Inspect the CNI configuration

On a worker:

```bash
ls /etc/cni/net.d/
cat /etc/cni/net.d/10-calico.conflist
ls /opt/cni/bin/ | grep calico
```

**Expected result:** `10-calico.conflist` exists, its JSON names the `calico` plugin type
with `"datastore_type": "kubernetes"`, and `/opt/cni/bin/` contains `calico` and
`calico-ipam`.

`/etc/cni/net.d/` is what the kubelet reads to decide which plugin to invoke for every new
pod, and `/opt/cni/bin/` is where it finds the executable. The `calico-node` DaemonSet put
both there — which is why a CNI must be a DaemonSet, and why deleting it breaks pod
creation on every node.

---

## Step 5 — Clean up the test pods

```bash
kubectl delete pod pod-a pod-b
```

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — pre-check and install | no existing CNI; then a long list of `created` resources |
| Step 2 — nodes Ready | `calico-node` `2 of 2`, both nodes `Ready`, CoreDNS `Running` |
| Step 3 — cross-node ping | pods on different nodes with `192.168.x.x` IPs; `0% packet loss` |
| Step 4 — on-disk CNI | `10-calico.conflist` present; `calico` and `calico-ipam` in `/opt/cni/bin/` |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Pods never get an IP, two CNIs installed | Remove one: delete its manifest, `sudo rm -f /etc/cni/net.d/*`, then restart the kubelet. |
| Nodes stay `NotReady` after applying Calico | `kubectl -n kube-system describe pod -l k8s-app=calico-node` — usually still pulling images on a slow playground. |
| `calico-node` pods `CrashLoopBackOff` | Check its logs for an IP-pool/pod-CIDR mismatch against the `--pod-network-cidr` from Lab 2. |
| CoreDNS still `Pending` | The pod network is not up yet; wait for `rollout status ds/calico-node`. |
| `pod-a` stays `Pending` | `nodeName` must match exactly: check `kubectl get nodes` for the real name. |
| Cross-node ping fails but same-node works | An overlay problem — check for blocked IP-in-IP/VXLAN traffic and `calico-node` logs on both nodes. |

---

## What you learned
- How a CNI plugin turns `NotReady` nodes into `Ready` ones.
- Where CNI config and binaries live on each node.
- A practical cross-node connectivity test.
