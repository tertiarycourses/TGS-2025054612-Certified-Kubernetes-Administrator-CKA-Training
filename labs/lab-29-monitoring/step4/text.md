# Step 4 — Container-level stats via cAdvisor (reference)

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl get --raw "/api/v1/nodes/$NODE/proxy/stats/summary" | head -50
```

**Expected result:** a large JSON document beginning with the node's own CPU and memory
usage, followed by a `pods` array with per-container numbers.

This is cAdvisor inside the kubelet, and it is the *source* for everything else:
metrics-server summarises it for `kubectl top` and HPA, and Prometheus scrapes the related
`/metrics/cadvisor` endpoint. Useful when `kubectl top` is unavailable:

```bash
kubectl get --raw "/api/v1/nodes/$NODE/proxy/stats/summary" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["node"]["nodeName"], d["node"]["cpu"]["usageNanoCores"])'
```

**Expected result:** the node name and a raw nanocore figure.
