# Step 2 — Previous instance after a crash

```bash
kubectl run crashy --image=busybox -- /bin/sh -c "echo running; sleep 5; exit 1"
sleep 30
kubectl get pod crashy
kubectl logs crashy
kubectl logs crashy --previous
```

**Expected result:** the pod is `CrashLoopBackOff` with `RESTARTS` climbing. Plain
`kubectl logs` may fail with
`is waiting to start: ContainerCreating` or show only the newest attempt, while
`--previous` reliably prints `running` — the output of the instance that died.

That is the whole point: in a crash loop the interesting output belongs to a container that
no longer exists. `-p` is the first flag to reach for on `CrashLoopBackOff`.
