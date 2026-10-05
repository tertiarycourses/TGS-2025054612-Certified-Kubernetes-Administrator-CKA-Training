# Step 5 — etcd health

```bash
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health
```

**Expected result:**

```text
https://127.0.0.1:2379 is healthy: successfully committed proposal: took = 12ms
```

Anything else — a timeout, a certificate error — means etcd itself is the problem, and no
amount of apiserver debugging will help. Check the member list and sizes too:

```bash
sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint status --write-out=table
```

**Expected result:** one row: this member, its DB size, and `RAFT TERM`. A DB approaching
the 2 GB default quota is a real-world outage waiting to happen.
