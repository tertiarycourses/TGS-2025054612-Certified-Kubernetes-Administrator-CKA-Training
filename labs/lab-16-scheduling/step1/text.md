# Step 1 — Label your nodes

Pick the **worker**, not the control plane. The control-plane node already carries a
`node-role.kubernetes.io/control-plane:NoSchedule` taint, so labelling it would make every
result below misleading:

```bash
kubectl get nodes --show-labels
NODE=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  -o jsonpath='{.items[0].metadata.name}')
echo "working with: $NODE"
kubectl label node $NODE disktype=ssd tier=frontend
kubectl get nodes -L disktype,tier
```

**Expected result:** `$NODE` is `node01` (or your worker's name), and the table shows
`disktype=ssd` and `tier=frontend` against it only.

> Keep this shell open — `$NODE` is used in Steps 6 and 7. A new tab starts without it.
> Check the control plane's taint for yourself:
> `kubectl get node -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].spec.taints}'`
