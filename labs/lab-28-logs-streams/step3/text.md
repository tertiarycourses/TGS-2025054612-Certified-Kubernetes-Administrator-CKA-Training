# Step 3 — Multi-container pod

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

kubectl logs multi              # no -c: kubectl picks one for you
kubectl logs multi -c writer --tail=5
kubectl logs multi -c reader --tail=5
kubectl logs multi --all-containers --prefix --tail=10
```

**Expected result:** the bare `kubectl logs multi` **succeeds**, with a notice on stderr:

```text
Defaulted container "writer" out of: writer, reader
writer-0
writer-1
```

kubectl picks the **first** container rather than refusing — so on a multi-container pod you
can silently read the wrong one. Always pass `-c` when it matters. (Older kubectl did error
with `a container name must be specified`; current versions default instead.)

The targeted reads print `writer-N` and `reader-N`, and the last command interleaves both:

```text
[pod/multi/writer] writer-0
[pod/multi/writer] writer-1
[pod/multi/reader] reader-0
```

`--prefix` is what makes `--all-containers` readable, and both work with `-f` for live
multi-container tailing.

> A pod can choose its own default with the
> `kubectl.kubernetes.io/default-container` annotation — which is how sidecar-heavy
> workloads keep `kubectl logs` useful without `-c`.
