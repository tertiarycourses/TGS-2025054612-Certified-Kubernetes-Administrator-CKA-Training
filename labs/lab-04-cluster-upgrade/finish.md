# Well done!

You have completed Lab 4 — Cluster Upgrade with kubeadm:

✅ Read the starting version (**v1.36.x**) with `kubectl get nodes` and `kubeadm version`
✅ Repointed the Kubernetes apt repo from v1.36 to v1.37 and found the installable version
   with `apt-cache madison kubeadm`
✅ Upgraded the kubeadm binary, then ran `kubeadm upgrade plan` and `upgrade apply`
✅ Drained the node before restarting the kubelet, then uncordoned it
✅ Confirmed `kubectl get nodes` now reports **v1.37.x**

Compare the two if you want the evidence side by side:

```bash
cat /tmp/cluster-before.txt      # captured before the upgrade
kubectl get nodes -o wide        # now
```

**Next:** Lab 5 — Highly-Available Control Plane
