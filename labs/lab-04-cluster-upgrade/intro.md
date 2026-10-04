# Lab 4 — Cluster Upgrade with kubeadm

In this scenario you perform a **real minor upgrade**: the cluster starts on **v1.36** and
you take it to **v1.37**, following the recommended order — control plane first, then
workers, draining each node before the kubelet restart.

A **v1.36 single-node cluster is being provisioned in the background** while you read this.
It takes a couple of minutes. Wait for it before running Step 1:

```bash
until [ -f /tmp/cluster-ready ]; do sleep 5; done; echo READY
cat /tmp/cluster-start-version.txt     # the version you start from
kubectl get nodes
```

**What you will do:**
- Read the cluster's starting version, and the one minor the apt repo is pointed at
- Point apt at v1.37 and read the exact package version from `apt-cache madison`
- Plan and apply the control-plane upgrade with `kubeadm upgrade apply`
- Drain the control plane and upgrade its kubelet and kubectl
- Confirm `kubectl get nodes` now reports **v1.37.x** — a different minor than you started on

> This scenario is a **single node**, so it plays both roles. Step 6 (the worker) applies
> when you have a second node, such as the two-node playground.
