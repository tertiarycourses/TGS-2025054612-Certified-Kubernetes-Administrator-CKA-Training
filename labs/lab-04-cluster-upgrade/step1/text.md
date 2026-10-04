# Step 1 — Check what you are actually running

```bash
kubectl get nodes
kubeadm version -o short
kubelet --version
cat /etc/apt/sources.list.d/kubernetes.list
```

The apt repo URL ends in `core:/stable:/v1.NN/deb` and apt can install only what that one
minor publishes — which is why asking for a package from another minor fails with
`E: Version '1.35.0-1.1' for 'kubeadm' was not found`. Step 2 repoints it.
