# Step 1 — Single-container logs

```bash
kubectl create deployment chatty --image=busybox \
  -- /bin/sh -c "i=0; while true; do echo line-\$i; i=\$((i+1)); sleep 1; done"
kubectl wait --for=condition=Available deploy/chatty --timeout=60s
POD=$(kubectl get pod -l app=chatty -o name | head -1)
kubectl logs $POD --tail=10
kubectl logs $POD -f &
sleep 5
kill %1
```

**Expected result:** ten numbered lines (`line-0`, `line-1`, …) from `--tail`, then a few
more streaming live before `kill` stops the follow.

`kubectl logs` reads whatever the container wrote to stdout/stderr — no log agent, no
configuration. An app that writes to a *file* inside the container produces nothing here,
which is why containerised apps log to stdout.
