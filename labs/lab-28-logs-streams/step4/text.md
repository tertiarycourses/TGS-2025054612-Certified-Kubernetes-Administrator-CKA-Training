# Step 4 — Logs from the host (on the pod's own node)

**Container logs are node-local.** The kubelet that runs the pod writes them, so they exist
only on *that* node. The control plane is tainted, so your pods are on the worker — looking
on the control plane gives
`ls: cannot access '/var/log/pods/default_multi_*/writer/': No such file or directory`.

Find the node first, then read the files there:

```bash
NODE=$(kubectl get pod multi -o jsonpath='{.spec.nodeName}')
echo "logs live on: $NODE"
ssh $NODE "sudo ls /var/log/pods/ | grep default_multi"
ssh $NODE "sudo ls /var/log/pods/default_multi_*/writer/"
ssh $NODE "sudo tail -3 /var/log/pods/default_multi_*/writer/0.log"
```

**Expected result:** a directory named `default_multi_<uid>`, a `writer/` subdirectory, and
`0.log` inside it, whose lines look like:

```text
2026-10-07T09:14:02.123456789Z stdout F writer-0
```

Each line is the CRI log format: an RFC3339 timestamp, the stream (`stdout`/`stderr`), a
full/partial flag, then the raw output — this is what `kubectl logs` parses and why it can
offer `--timestamps` and `--since`.

> `kubectl logs` works from **anywhere** because the API server proxies the request to that
> node's kubelet. These files are the other side of that: available only on the node, and
> the reason `/var/log/pods` matters when the API server is down (Lab 26).
>
> On a single-node cluster, drop the `ssh $NODE` wrapper. Listing
> `/var/log/pods/` on the control plane still shows its **static** pods — `etcd`,
> `kube-apiserver` and friends — which is exactly the set you needed in Lab 26.

**Expected result:** a directory per pod named `<namespace>_<pod>_<uid>`, a subdirectory
per container, and `0.log` inside it. Each line begins with an RFC3339 timestamp, then
`stdout` or `stderr`, then the raw output — the CRI log format that `kubectl logs` parses.

```bash
CRASHY_NODE=$(kubectl get pod crashy -o jsonpath='{.spec.nodeName}')
ssh $CRASHY_NODE "sudo ls /var/log/pods/default_crashy_*/crashy/"
```

**Expected result:** **several** numbered files (`0.log`, `1.log`, …) — one per container
restart, on the node running `crashy`. `kubectl logs --previous` reads the second-newest,
and files beyond that are what you lose when a pod restarts enough times. Node-level log
rotation (`containerLogMaxFiles`) is the limit.

> Deleted the pod already? Its directory is removed with it, so run this while `crashy`
> still exists.
