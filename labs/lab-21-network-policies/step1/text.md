# Step 1 — Check your CNI enforces policy, then create the test pods

**Do this first.** A NetworkPolicy is only a *request*: the CNI plugin enforces it. Calico
and Cilium do; **Flannel does not** and ignores every policy silently — so the "blocked"
steps below would return `200` and teach you the opposite of the truth.

```bash
kubectl get pods -n kube-system -o name | grep -Ei 'calico|cilium|weave' || \
  echo "WARNING: no policy-enforcing CNI found - policies will be ignored"
ls /etc/cni/net.d/
```

**Expected result:** Calico or Cilium pods are listed. If you see the warning, or only
`flannel` in `/etc/cni/net.d/`, stop here and install Calico (Lab 3) — otherwise every
result in this lab is meaningless.

Now the test pods:

```bash
kubectl create ns netpol
kubectl -n netpol run server --image=nginx --labels="app=server"
kubectl -n netpol run client-ok --image=nicolaka/netshoot --labels="role=allowed" --command -- sleep 3600
kubectl -n netpol run client-bad --image=nicolaka/netshoot --labels="role=denied" --command -- sleep 3600
kubectl -n netpol expose pod server --port=80
kubectl -n netpol wait --for=condition=Ready pod --all --timeout=60s
```
