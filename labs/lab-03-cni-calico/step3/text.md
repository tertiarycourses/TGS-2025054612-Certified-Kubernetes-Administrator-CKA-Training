# Step 3 — Verify pod networking across nodes

Schedule two pods, one on each node:

```bash
kubectl run pod-a --image=nicolaka/netshoot --overrides='{"spec":{"nodeName":"controlplane"}}' --command -- sleep 3600
kubectl run pod-b --image=nicolaka/netshoot --overrides='{"spec":{"nodeName":"node01"}}'     --command -- sleep 3600
kubectl wait --for=condition=Ready pod/pod-a pod/pod-b --timeout=120s
kubectl get pods -o wide
```

**Expected result:** both pods `Running`, on **different** nodes, each with an IP from
`192.168.0.0/16`.

> Note the trick: `nodeName` in the overrides bypasses the scheduler entirely, so `pod-a`
> lands on the control plane **despite** its `NoSchedule` taint — taints are enforced when
> scheduling, and this pod was never scheduled.

Ping pod-b from pod-a:

```bash
POD_B_IP=$(kubectl get pod pod-b -o jsonpath='{.status.podIP}')
kubectl exec pod-a -- ping -c 3 $POD_B_IP
```

**Expected result:** `3 packets transmitted, 3 received, 0% packet loss`.

That is cross-node pod traffic: the packet left one node, crossed Calico's overlay
(IP-in-IP or VXLAN depending on the detected environment) and arrived at a pod on the other
node — with no NAT and no port mapping. If this fails while both pods are `Running`, the
overlay is the problem, not Kubernetes.
