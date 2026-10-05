# Step 2 — Find etcd's endpoint, certificates and data directory

Never guess these — they are in the static-pod manifest that defines etcd:

```bash
sudo grep -E "data-dir|listen-client-urls|--cert-file|--key-file|trusted-ca-file" \
  /etc/kubernetes/manifests/etcd.yaml
sudo grep -n -B2 "name: etcd-data" /etc/kubernetes/manifests/etcd.yaml
```

**Expected result:** client URL `https://127.0.0.1:2379`, server cert and key under
`/etc/kubernetes/pki/etcd/`, `--data-dir=/var/lib/etcd` inside the container, and a
`hostPath` of `/var/lib/etcd` on the node.

Install the client tools on the node — the restore must run on the host, while etcd is
stopped, so an exec into the pod will not do:

```bash
sudo apt-get update -qq && sudo apt-get install -y etcd-client
etcdctl version
```

If that package is unavailable, or `etcdutl` is missing from it, take both binaries
straight from an official etcd release:

```bash
ETCD_VER=v3.5.21
curl -sL "https://github.com/etcd-io/etcd/releases/download/$ETCD_VER/etcd-$ETCD_VER-linux-amd64.tar.gz" \
  -o /tmp/etcd.tar.gz
sudo tar xzf /tmp/etcd.tar.gz -C /usr/local/bin --strip-components=1 \
  "etcd-$ETCD_VER-linux-amd64/etcdctl" "etcd-$ETCD_VER-linux-amd64/etcdutl"
etcdctl version && etcdutl version
```

Set the connection details once, so every command below is short:

```bash
export ETCDCTL_API=3
CA=/etc/kubernetes/pki/etcd/ca.crt
CERT=/etc/kubernetes/pki/etcd/server.crt
KEY=/etc/kubernetes/pki/etcd/server.key
EP=https://127.0.0.1:2379
```

Confirm you can reach etcd:

```bash
sudo ETCDCTL_API=3 etcdctl --endpoints=$EP --cacert=$CA --cert=$CERT --key=$KEY \
  endpoint health
```

**Expected result:** `https://127.0.0.1:2379 is healthy`. If you get a certificate error,
re-read the paths from the manifest above — wrong flags are the most common exam mistake.
