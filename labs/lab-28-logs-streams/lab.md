# Lab 28 — Application Logs and Container Streams

Containers emit logs to `stdout` and `stderr`. The kubelet redirects these to `/var/log/pods/...`, and `kubectl logs` reads them back. In this lab you inspect single-container, multi-container, and previous-instance logs, then look at the files on disk.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Single-container logs

```bash
kubectl create deployment chatty --image=busybox \
  -- /bin/sh -c "i=0; while true; do echo line-\$i; i=\$((i+1)); sleep 1; done"
kubectl wait --for=condition=Available deploy/chatty --timeout=60s
POD=$(kubectl get pod -l app=chatty -o name | head -1)
kubectl logs $POD --tail=10
kubectl logs $POD -f &
sleep 5
kill %1
```

**Expected result:** ten numbered lines (`line-0`, `line-1`, …) from `--tail`, then a few
more streaming live before `kill` stops the follow.

`kubectl logs` reads whatever the container wrote to stdout/stderr — no log agent, no
configuration. An app that writes to a *file* inside the container produces nothing here,
which is why containerised apps log to stdout.

---

## Step 2 — Previous instance after a crash

```bash
kubectl run crashy --image=busybox -- /bin/sh -c "echo running; sleep 5; exit 1"
sleep 30
kubectl get pod crashy
kubectl logs crashy
kubectl logs crashy --previous
```

**Expected result:** the pod is `CrashLoopBackOff` with `RESTARTS` climbing. Plain
`kubectl logs` may fail with
`is waiting to start: ContainerCreating` or show only the newest attempt, while
`--previous` reliably prints `running` — the output of the instance that died.

That is the whole point: in a crash loop the interesting output belongs to a container that
no longer exists. `-p` is the first flag to reach for on `CrashLoopBackOff`.

---

## Step 3 — Multi-container pod

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: multi }
spec:
  containers:
  - name: writer
    image: busybox
    command: ["sh","-c","i=0;while true;do echo writer-$i;i=$((i+1));sleep 1;done"]
  - name: reader
    image: busybox
    command: ["sh","-c","i=0;while true;do echo reader-$i;i=$((i+1));sleep 2;done"]
EOF
kubectl wait --for=condition=Ready pod/multi --timeout=60s

kubectl logs multi              # error: needs -c
kubectl logs multi -c writer --tail=5
kubectl logs multi -c reader --tail=5
kubectl logs multi --all-containers --prefix --tail=10
```

**Expected result:** the bare `kubectl logs multi` **fails** with
`a container name must be specified for pod multi, choose one of: [writer reader]`. The
targeted reads print `writer-N` and `reader-N`, and the last command interleaves both with
`[pod/multi/writer]`-style prefixes.

`--prefix` is what makes `--all-containers` readable, and both work with `-f` for live
multi-container tailing.

---

## Step 4 — Logs from the host

```bash
ls /var/log/pods/
ls /var/log/pods/default_multi_*/writer/
sudo tail /var/log/pods/default_multi_*/writer/0.log
```

**Expected result:** a directory per pod named `<namespace>_<pod>_<uid>`, a subdirectory
per container, and `0.log` inside it. Each line begins with an RFC3339 timestamp, then
`stdout` or `stderr`, then the raw output — the CRI log format that `kubectl logs` parses.

```bash
sudo ls /var/log/pods/default_crashy_*/crashy/
```

**Expected result:** **several** numbered files (`0.log`, `1.log`, …) — one per container
restart. `kubectl logs --previous` reads the second-newest, and files beyond that are what
you lose when a pod restarts enough times. Node-level log rotation
(`containerLogMaxFiles`) is the limit.

---

## Step 5 — Multi-pod tail with stern (optional)

```bash
curl -sL https://github.com/stern/stern/releases/download/v1.34.0/stern_1.34.0_linux_amd64.tar.gz \
  | sudo tar -xz -C /usr/local/bin stern
stern --version
stern chatty --tail 5
```

**Expected result:** `stern` prints its version, then follows the `chatty` pods with each
line prefixed by pod and container name. Ctrl-C to stop.

`stern` takes a **regex** over pod names and follows across pods, containers and namespaces
at once — `kubectl logs` needs an exact pod. Try `stern . -n kube-system --tail 1` to watch
the whole control plane.

> Installed straight from the release tarball and pinned: the previous `go install` path
> needs a Go toolchain the playground does not have, and an unpinned version has changed
> flags between course runs.

---

## Step 6 — Cleanup

```bash
kubectl delete deploy chatty
kubectl delete pod crashy multi --ignore-not-found
```

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — basic logs | numbered `line-N` output, then live streaming |
| Step 2 — previous | `CrashLoopBackOff`; `--previous` prints `running` |
| Step 3 — multi-container | bare `logs` errors asking for `-c`; `--prefix` interleaves both |
| Step 4 — on disk | `/var/log/pods/<ns>_<pod>_<uid>/<container>/0.log`, one file per restart |
| Step 5 — stern | version printed, logs followed across pods with prefixes |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `a container name must be specified` | Multi-container pod: add `-c <name>` or `--all-containers`. |
| `previous terminated container not found` | The container has not restarted yet — wait for `RESTARTS` to be at least 1. |
| `kubectl logs` is empty | The app logs to a file inside the container, not to stdout. |
| `permission denied` under /var/log/pods | Use `sudo` — those files are root-owned. |
| `stern: command not found` after install | The tarball extracts one binary; confirm with `ls -l /usr/local/bin/stern`. |
| Old logs have disappeared | Node log rotation (`containerLogMaxSize`/`containerLogMaxFiles`) discards them; ship logs off-node for retention. |

---

## What you learned
- `kubectl logs`, `-f`, `-p`, `-c`, `--all-containers`.
- The kubelet log path `/var/log/pods/<ns>_<pod>_<uid>/<container>/0.log`.
- `stern` for multi-pod tails.
