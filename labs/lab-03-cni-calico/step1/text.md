# Step 1 — Check for an existing CNI, then apply Calico

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
