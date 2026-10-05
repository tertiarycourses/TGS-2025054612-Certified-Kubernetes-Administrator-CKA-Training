# Step 7 — Pending due to nodeSelector

```bash
kubectl -n app run picky --image=nginx \
  --overrides='{"spec":{"nodeSelector":{"zone":"never"}}}'
kubectl -n app describe pod picky | grep -A4 Events
```

**Expected result:** `Pending` with
`0/2 nodes are available: 2 node(s) didn't match Pod's node affinity/selector`.

Three different `Pending` causes, three different messages — resources, taints, selectors.
**`kubectl describe pod` Events names which one every time**, which is why it is the first
command for any `Pending` pod. Fix it by labelling a node or correcting the selector:

```bash
kubectl label node $NODE zone=never
sleep 5
kubectl -n app get pod picky -o wide
```

**Expected result:** `picky` now schedules — unless the taint from Step 6 is still in place,
in which case the event changes to the taint message. Clean up the label:
`kubectl label node $NODE zone-`.
