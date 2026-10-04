# Lab 5 — Highly-Available Control Plane

A real HA control plane needs three machines with 2 CPUs each, and this environment gives
you two 1-CPU nodes — so instead of pretending, you build every piece of HA that *is*
reproducible on one control plane, and check each result.

**Prerequisite:** a running cluster (Lab 2). Verify with `kubectl get nodes`.

**What you will do:**
- Measure your cluster: control-plane count, missing `controlPlaneEndpoint`, etcd members, quorum maths
- Run HAProxy on port 8443 in front of the apiserver and reach the API through it
- See the `x509 … not k8s-vip` error that explains why the endpoint must be in the certificate
- Rebuild with `--control-plane-endpoint` + `--upload-certs` and join the worker through the load balancer
- Generate a real control-plane join command with a certificate key

> Step 4 deliberately resets the cluster from Lab 2.
