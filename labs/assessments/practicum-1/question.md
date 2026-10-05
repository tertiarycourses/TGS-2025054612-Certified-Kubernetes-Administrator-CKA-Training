# Practicum 1 — Cluster Architecture, Installation & Configuration (Domain 1)

> **Day 1 assessment  ·  Time allowed: 45 minutes**  
> Platform: [Killercoda Kubernetes Playground](https://killercoda.com/playgrounds/scenario/kubernetes)

---

## Task 1 — Bootstrap a kubeadm cluster (10 pts)

You are given a fresh two-node Ubuntu environment on Killercoda (kubeadm scenario).

1. On **both** nodes: load the `overlay` and `br_netfilter` kernel modules, set the required `net.ipv4.ip_forward` sysctl, disable swap, install `containerd` with `SystemdCgroup = true`, and install `kubeadm`, `kubelet`, and `kubectl` from `pkgs.k8s.io`.

   > Use whichever minor the environment already provides — read it with `kubeadm version -o short` and point the apt repo at that same minor (`core:/stable:/v1.NN/deb`). Do **not** install a different minor over a running cluster. If the playground already has a cluster, reset it first (`kubeadm reset -f`), as in Lab 2.

2. On the **control-plane** node: initialise the cluster with `kubeadm init --pod-network-cidr=192.168.0.0/16`. Add `--ignore-preflight-errors=NumCPU` if the node has only 1 CPU. Copy `admin.conf` to `~/.kube/config`.

3. On the **worker** node: join the cluster using the `kubeadm join` command printed by `kubeadm init`.

**Verify:** `kubectl get nodes` shows both nodes with status **Ready**.

---

## Task 2 — Install a CNI plugin (5 pts)

Apply the Calico operator manifest to enable pod networking.

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/tigera-operator.yaml
```

Create a `Installation` CR with `cidr: 192.168.0.0/16` and wait for all `calico-*` pods to be `Running`.

**Verify:** `kubectl get pods -n calico-system` — all pods Running.

---

## Task 3 — Configure RBAC (10 pts)

1. Create a **ServiceAccount** named `app-reader` in namespace `team-a`.
2. Create a **Role** named `pod-reader` in namespace `team-a` that allows `get`, `list`, `watch` on `pods`.
3. Create a **RoleBinding** that binds `pod-reader` to `app-reader`.
4. Verify: `kubectl auth can-i list pods --as=system:serviceaccount:team-a:app-reader -n team-a` returns `yes`.

---

## Task 4 — Install a Helm chart (5 pts)

1. Add a chart repo: `helm repo add podinfo https://stefanprodan.github.io/podinfo`.
2. Install `podinfo/podinfo` as release name `web` in namespace `web` (create it) with `replicaCount=2`.
3. Upgrade the release to `replicaCount=3`, then show the revision history.
4. Roll back to revision 1 and confirm the replica count returns to 2.

**Verify:** `kubectl get pods -n web` shows 3 Running pods after the upgrade, `helm -n web history web` lists the revisions, and the rollback returns the Deployment to 2 replicas.

> **Not Bitnami.** Most Helm material still says `helm repo add bitnami https://charts.bitnami.com/bitnami`, but that catalog was retired: `helm pull bitnami/nginx` now returns **403**, and older pinned charts reference image tags that return **404**. Recognising those two failures is itself examinable — see Lab 6, Step 8.
