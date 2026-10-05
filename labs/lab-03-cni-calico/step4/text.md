# Step 4 — Inspect the CNI configuration

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
