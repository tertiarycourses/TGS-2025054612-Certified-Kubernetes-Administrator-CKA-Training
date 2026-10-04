# Step 1 — Check what you are actually running

First make sure the background provisioning has finished:

```bash
until [ -f /tmp/cluster-ready ]; do sleep 5; done; echo READY
```

```bash
kubectl get nodes
kubeadm version -o short
kubelet --version
cat /etc/apt/sources.list.d/kubernetes.list
```

You start on **v1.36.x**, and the list line ends in `core:/stable:/v1.36/deb`. The apt repo
serves that one minor only, which is why asking for a v1.37 package right now would fail
with `E: Version '1.37.x-1.1' for 'kubeadm' was not found`. Step 2 repoints it.

Note the version in the `VERSION` column — at the end of the lab it must read `v1.37.x`.
