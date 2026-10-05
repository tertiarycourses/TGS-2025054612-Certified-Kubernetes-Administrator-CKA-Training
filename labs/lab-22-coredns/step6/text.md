# Step 6 — Customize the Corefile

Add a stub zone that forwards `example.com` to a public resolver. Back the Corefile up
first, and do it without an interactive editor:

```bash
kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' > /tmp/Corefile.bak
cp /tmp/Corefile.bak /tmp/Corefile.new
cat >> /tmp/Corefile.new <<'EOF'
example.com:53 {
    errors
    forward . 8.8.8.8
}
EOF
kubectl -n kube-system create configmap coredns \
  --from-file=Corefile=/tmp/Corefile.new \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n kube-system rollout restart deploy coredns
kubectl -n kube-system rollout status deploy coredns --timeout=120s
```

**Expected result:** the rollout completes and the new zone is in place:

```bash
kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' | tail -5
kubectl exec dnsdebug -- dig +short www.example.com
```

**Expected result:** the Corefile ends with your `example.com:53` block, and the query
returns public IP addresses — resolved through the stub zone rather than the cluster zone.

> **A broken Corefile breaks all cluster DNS.** CoreDNS will `CrashLoopBackOff` and every
> pod loses name resolution. That is why you saved a backup: restore with
>
> ```bash
> kubectl -n kube-system create configmap coredns --from-file=Corefile=/tmp/Corefile.bak \
>   --dry-run=client -o yaml | kubectl apply -f -
> kubectl -n kube-system rollout restart deploy coredns
> ```
