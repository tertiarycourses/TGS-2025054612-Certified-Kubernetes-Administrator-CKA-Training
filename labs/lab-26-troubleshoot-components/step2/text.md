# Step 2 — Break the API server

```bash
sudo sed -i 's|--secure-port=6443|--secure-port=6444|' /etc/kubernetes/manifests/kube-apiserver.yaml
```

Within ~20 s the kubelet re-creates the pod with the bad port.

Give the kubelet ~20 seconds to notice the changed file, then:

```bash
sleep 25
kubectl get nodes
```

**Expected result:** `The connection to the server … was refused`. The API server is now
listening on 6444 while every kubeconfig and its own liveness probe still use 6443, so the
kubelet keeps restarting it.

> This is the most realistic control-plane failure there is: a one-character edit in a
> static-pod manifest, and the cluster is unreachable.
