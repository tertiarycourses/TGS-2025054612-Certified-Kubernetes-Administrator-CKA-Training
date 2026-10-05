# Step 1 — Prepare a host directory on the node that will run the pod

`hostPath` reads a directory **on one specific node**. The control plane is tainted, so
your pod will land on the worker — create the directory *there*, or the pod mounts an empty
directory and the check in Step 4 fails.

```bash
TARGET=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  -o jsonpath='{.items[0].metadata.name}')
echo "pod will run on: $TARGET"
ssh $TARGET "sudo mkdir -p /mnt/data && echo 'hello from host' | sudo tee /mnt/data/index.html"
```

**Expected result:** `hello from host` echoed back from the worker node.

> On the KillerCoda two-node playground `ssh node01` works from the control plane without a
> password. If you only have one node, run the commands locally without `ssh` — `$TARGET`
> is then the control plane itself.
