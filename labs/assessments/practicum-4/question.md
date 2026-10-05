# Practicum 4 — Troubleshooting + Final Mock (Domain 5 + all domains)

> **Day 4 assessment  ·  Time allowed: 2 hours**  
> Platform: [Killercoda Kubernetes Playground](https://killercoda.com/playgrounds/scenario/kubernetes)

---

## Part A — Troubleshooting (1 hour)

### Task 1 — Fix a broken cluster component (15 pts)

The kube-scheduler static pod on the control plane has a deliberately broken manifest (`/etc/kubernetes/manifests/kube-scheduler.yaml`). The scheduler binary path has been changed to `/usr/bin/kube-scheduler-broken`.

1. SSH to the control-plane node.
2. Inspect the scheduler pod: `crictl ps -a | grep scheduler`.
3. Edit the manifest to restore the correct binary path: `/usr/bin/kube-scheduler`.
4. Wait for the kubelet to restart the static pod (~30 s).

**Verify:** `kubectl get pods -n kube-system | grep scheduler` shows `Running`. New pods scheduled normally.

---

### Task 2 — Recover a NotReady node (10 pts)

Worker node `node01` is in `NotReady` state. The kubelet service has stopped.

1. SSH to `node01`.
2. Check status: `systemctl status kubelet`.
3. Read logs: `journalctl -u kubelet -n 50`.
4. Fix the root cause (containerd or kubelet configuration), then `systemctl start kubelet`.

**Verify:** `kubectl get nodes` shows `node01` as `Ready`.

---

### Task 3 — Troubleshoot a broken Service (10 pts)

A Deployment `api-server` (namespace `backend`) is running but the Service `api-svc` is returning no endpoints.

1. Inspect: `kubectl get endpoints api-svc -n backend`.
2. Compare the Service selector to the Pod labels.
3. Fix the label mismatch so the Service routes to the correct Pods.

**Verify:** `kubectl get endpoints api-svc -n backend` shows at least one endpoint IP.

---

### Task 4 — Fix an RBAC 403 error (5 pts)

A CI pipeline ServiceAccount `ci-runner` in namespace `ci` is getting `403 Forbidden` when running `kubectl get pods`.

1. Check: `kubectl auth can-i get pods --as=system:serviceaccount:ci:ci-runner -n ci`.
2. Create a **Role** and **RoleBinding** to grant the missing permission.

**Verify:** The `auth can-i` command above returns `yes`.

---

## Part B — Final Mock Exam (1 hour)

Work through CKA-style tasks covering all five domains using the [Tertiary Infotech CKA Practice Exam](https://exams.tertiaryinfotech.com/practice-exams/linuxfoundation/linuxfoundation-cka). Time yourself — the real exam allows 2 hours for ~15–20 tasks.

Suggested focus areas:
- etcd snapshot and restore: `etcdctl snapshot save` with `--endpoints`, `--cacert`, `--cert`, `--key` — and remember that **restore** is `etcdutl snapshot restore` on etcd 3.5+ (removed from `etcdctl` in 3.6), into a **new** `--data-dir`, with the `etcd.yaml` hostPath repointed. See Lab 5.
- Cluster upgrade: `kubeadm upgrade plan` → `apply` → worker drain/upgrade
- Deploy + expose + Ingress pipeline
- PVC binding and StatefulSet volumeClaimTemplates
- Systematic pod troubleshooting: describe → logs → exec

---

> **Exam tip:** On the real CKA exam, flag hard tasks and move on — the last 20 minutes for revisits is where many candidates gain the marks that push them past 66%.
