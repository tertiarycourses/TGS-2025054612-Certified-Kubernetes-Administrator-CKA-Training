# Step 4 — Fix

```bash
sudo sed -i 's|--secure-port=6444|--secure-port=6443|' /etc/kubernetes/manifests/kube-apiserver.yaml
```

The kubelet re-reads the manifest within ~20 seconds and recreates the pod, so wait for
the API rather than guessing:

```bash
until kubectl get --raw=/readyz > /dev/null 2>&1; do echo "waiting for the API..."; sleep 5; done
kubectl get nodes
kubectl -n kube-system get pods -l component=kube-apiserver
```

**Expected result:** the API answers again, both nodes are `Ready`, and the apiserver pod is
`Running` with a non-zero `RESTARTS` count — evidence of what you just did. Recovery needs
no `systemctl` and no `kubectl`: fixing the file is enough, because the kubelet is watching
it.
