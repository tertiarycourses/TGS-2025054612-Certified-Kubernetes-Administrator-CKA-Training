# Lab 4 — Cluster Upgrade with kubeadm

In this lab you upgrade a kubeadm cluster by one minor version, following the recommended order: control plane first, then workers, draining each node before the kubelet restart. This scenario provisions a **v1.34** cluster, so the target is **v1.35** — but you will read the exact package version from `apt-cache madison` rather than hard-coding it, because the Kubernetes apt repo serves one minor at a time.

A **v1.34 cluster is being provisioned in the background** — it will be ready by the time you finish reading this intro. Wait for the prompt to return before running Step 1 commands.

**What you will do:**
- Check current cluster and component versions
- Point apt at the target minor and upgrade the kubeadm binary
- Plan and apply the control-plane upgrade with `kubeadm upgrade apply`
- Drain the control plane and upgrade its kubelet and kubectl
- Repeat the drain-upgrade-uncordon cycle on the worker node
