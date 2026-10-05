# Step 1 — Check what you are actually running

```bash
kubectl get nodes
kubeadm version -o short
kubelet --version
cat /etc/apt/sources.list.d/kubernetes.list
```

**Expected result:** both nodes `Ready` on the same version, `kubeadm version -o short`
and `kubelet --version` agreeing, and a sources list ending in `core:/stable:/v1.NN/deb`.

Note two things before you touch anything:

- **The Kubernetes apt repo is pinned to one minor version.** The URL ends in
  `core:/stable:/v1.NN/deb`, and apt can install **only** the versions that one minor
  publishes. Asking for a package from a different minor fails like this:

  ```text
  E: Version '1.35.0-1.1' for 'kubeadm' was not found
  ```

  That is not a broken mirror — it is apt telling you the repo is pointed somewhere else.
  Step 2 repoints it.

- **You cannot upgrade downwards.** Compare `kubeadm version -o short` with the target in
  Step 2. If the cluster is already **newer** than the target (the shared two-node
  playground currently ships `v1.37.x`), skip to
  [Where to do a real upgrade](#where-to-do-a-real-upgrade) instead of installing
  older packages over a running cluster.
