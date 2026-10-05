# Step 2 — Ping by pod IP

```bash
SERVER_IP=$(kubectl get pod server -o jsonpath='{.status.podIP}')
kubectl exec client -- ping -c 3 $SERVER_IP
```

**Expected result:** `3 packets transmitted, 3 received, 0% packet loss`.

Now prove there is no NAT — ask the server what address the request came from:

```bash
kubectl exec client -- curl -s $SERVER_IP > /dev/null
kubectl logs server | tail -2
kubectl get pod client -o jsonpath='{.status.podIP}{"\n"}'
```

**Expected result:** the nginx access log shows **the client pod's own IP**, identical to
the second command's output. No SNAT, no port mapping: that flat, NAT-free pod network is
the Kubernetes network model.
