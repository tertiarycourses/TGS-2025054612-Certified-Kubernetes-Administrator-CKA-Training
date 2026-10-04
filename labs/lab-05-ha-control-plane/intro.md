# Lab 5 — HA Control Plane Overview and etcd Backup/Restore

A real HA control plane needs three machines with 2 CPUs each, which this environment
cannot give you — so HA is covered as a **high-level overview** (topology, quorum, and the
bootstrap flags that make a cluster HA-ready), and the hands-on work is **etcd backup and
restore**: the task a CKA is actually asked to perform on a single control plane.

**Prerequisite:** a working cluster. Check with `kubectl get nodes`.

**What you will do:**
- Review the stacked-etcd topology and the quorum table, and check whether your cluster is HA-ready
- Read etcd's endpoint, certificates and data directory out of its static-pod manifest
- Create a Deployment, Service and ConfigMap worth protecting
- Take a snapshot and verify it with `snapshot status`
- Delete the namespace, then restore etcd and watch every object come back
