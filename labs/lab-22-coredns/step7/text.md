# Step 7 — Cleanup

```bash
kubectl -n kube-system create configmap coredns --from-file=Corefile=/tmp/Corefile.bak \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n kube-system rollout restart deploy coredns
kubectl -n kube-system rollout status deploy coredns --timeout=120s
kubectl delete pod dnsdebug
kubectl delete svc web web-h
kubectl delete deploy web
```

**Expected result:** the Corefile is back to the backup and CoreDNS is `Running`. **Revert
the Corefile before other labs** — a stub zone left behind causes confusing DNS results
later.
