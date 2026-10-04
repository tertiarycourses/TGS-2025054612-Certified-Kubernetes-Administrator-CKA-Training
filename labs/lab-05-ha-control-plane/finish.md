# Well done!

You have completed Lab 5 — Highly-Available Control Plane:

✅ Showed your cluster was not HA-ready: one control plane, no `controlPlaneEndpoint`,
   one etcd member
✅ Ran HAProxy on `*:8443` in front of the apiserver and reached the API through it
✅ Reproduced the `x509: certificate is valid for …, not k8s-vip` failure, and explained it
   from the certificate's SAN list
✅ Rebuilt the cluster with `--control-plane-endpoint k8s-vip:8443 --upload-certs`, so every
   kubeconfig points at the load balancer
✅ Joined node01 through the endpoint and generated a real
   `kubeadm join … --control-plane --certificate-key …` command
✅ Computed etcd quorum and explained why control planes come in odd numbers

**Next:** Lab 6 — Install Components with Helm
