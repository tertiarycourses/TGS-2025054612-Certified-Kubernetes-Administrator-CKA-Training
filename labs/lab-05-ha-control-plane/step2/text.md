# Step 2 — Find etcd's endpoint, certificates and data directory

Read them from the static-pod manifest rather than guessing:

```bash
sudo grep -E "data-dir|listen-client-urls|--cert-file|--key-file|trusted-ca-file" \
  /etc/kubernetes/manifests/etcd.yaml
sudo grep -n -B2 "name: etcd-data" /etc/kubernetes/manifests/etcd.yaml
```

Client URL `https://127.0.0.1:2379`, certificates under `/etc/kubernetes/pki/etcd/`, and a
`hostPath` of `/var/lib/etcd`.

The restore runs on the host while etcd is stopped, so install the client there:

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

```bash
export ETCDCTL_API=3
CA=/etc/kubernetes/pki/etcd/ca.crt
CERT=/etc/kubernetes/pki/etcd/server.crt
KEY=/etc/kubernetes/pki/etcd/server.key
EP=https://127.0.0.1:2379
```

```bash
sudo ETCDCTL_API=3 etcdctl --endpoints=$EP --cacert=$CA --cert=$CERT --key=$KEY \
  endpoint health
```

`https://127.0.0.1:2379 is healthy`. A certificate error means wrong flags — the most
common exam mistake.
