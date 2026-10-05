# Lab 25 — Volume Types in Pods

Beyond PVCs, pods can mount many in-tree volume types: `emptyDir`, `hostPath`, `configMap`, `secret`, `projected`, `downwardAPI`. In this lab you exercise each of them.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — emptyDir (scratch space, pod lifetime)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: scratch }
spec:
  containers:
  - name: writer
    image: busybox
    command: ["sh","-c","echo hello > /data/file; sleep 3600"]
    volumeMounts: [{ name: tmp, mountPath: /data }]
  - name: reader
    image: busybox
    command: ["sh","-c","cat /data/file; sleep 3600"]
    volumeMounts: [{ name: tmp, mountPath: /data }]
  volumes:
  - name: tmp
    emptyDir: {}
EOF
kubectl wait --for=condition=Ready pod/scratch --timeout=60s
kubectl logs scratch -c reader
```

**Expected result:** `hello` — written by the `writer` container, read by `reader` through
the shared `emptyDir`.

```bash
kubectl exec scratch -c reader -- df -h /data | tail -1
```

**Expected result:** the mount is backed by the node's disk (an `overlay` or `/dev/...`
line). `emptyDir: {}` lives on disk; add `medium: Memory` to make it tmpfs. Either way it
is created when the pod starts and **deleted with the pod** — scratch space, never
storage.

---

## Step 2 — hostPath (node directory)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: hostpath-demo }
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh","-c","ls /host/etc/hostname; cat /host/etc/hostname; sleep 3600"]
    volumeMounts: [{ name: etc, mountPath: /host/etc, readOnly: true }]
  volumes:
  - name: etc
    hostPath: { path: /etc, type: Directory }
EOF
kubectl wait --for=condition=Ready pod/hostpath-demo --timeout=60s
kubectl logs hostpath-demo
kubectl get pod hostpath-demo -o jsonpath='{.spec.nodeName}{"\n"}'
```

**Expected result:** the log prints the **node's** hostname (not the pod's), and the last
command names the node it read from. You are looking at the host's `/etc` from inside a
container.

⚠️ `hostPath` couples the pod to a specific node and is a security risk — admission controllers usually restrict it.

---

## Step 3 — configMap and secret as files

Done in Lab 12 and Lab 13 — re-check:

```bash
kubectl create configmap demo-cfg --from-literal=greeting=hi
kubectl create secret generic demo-sec --from-literal=token=s3cret

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: mount-demo }
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh","-c","cat /cfg/greeting /sec/token; sleep 3600"]
    volumeMounts:
    - { name: cfg, mountPath: /cfg }
    - { name: sec, mountPath: /sec }
  volumes:
  - { name: cfg, configMap: { name: demo-cfg } }
  - { name: sec, secret:    { secretName: demo-sec } }
EOF
kubectl wait --for=condition=Ready pod/mount-demo --timeout=60s
kubectl logs mount-demo
kubectl exec mount-demo -- df -h /cfg /sec | tail -2
```

**Expected result:** `hi` then `s3cret`, and both mounts report **`tmpfs`** — ConfigMap and
Secret volumes are memory-backed, so their contents are never written to the node's disk.

---

## Step 4 — projected (combine many sources)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: projected-demo }
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh","-c","ls -la /proj; cat /proj/greeting /proj/token; sleep 3600"]
    volumeMounts: [{ name: all, mountPath: /proj }]
  volumes:
  - name: all
    projected:
      sources:
      - configMap: { name: demo-cfg }
      - secret:    { name: demo-sec }
EOF
kubectl wait --for=condition=Ready pod/projected-demo --timeout=60s
kubectl logs projected-demo
```

**Expected result:** the listing shows **both** `greeting` and `token` under `/proj`,
followed by `hi` and `s3cret`.

One mount point, two sources — which is how a pod receives a ServiceAccount token, a CA
bundle and its namespace from a single `projected` volume (look at any pod's
`/var/run/secrets/kubernetes.io/serviceaccount`).

---

## Step 5 — downwardAPI (pod metadata as files)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: downward-demo
  labels: { tier: web, env: prod }
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh","-c","cat /info/labels /info/name; sleep 3600"]
    volumeMounts: [{ name: info, mountPath: /info }]
  volumes:
  - name: info
    downwardAPI:
      items:
      - path: labels
        fieldRef: { fieldPath: metadata.labels }
      - path: name
        fieldRef: { fieldPath: metadata.name }
EOF
kubectl wait --for=condition=Ready pod/downward-demo --timeout=60s
kubectl logs downward-demo
```

**Expected result:**

```text
env="prod"
tier="web"
downward-demo
```

The pod's own labels and name, delivered as files. `downwardAPI` is how an app learns its
identity without calling the API server — no RBAC, no client library.

---

## Step 6 — Cleanup

```bash
kubectl delete pod scratch hostpath-demo mount-demo projected-demo downward-demo
kubectl delete configmap demo-cfg
kubectl delete secret demo-sec
```

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — emptyDir | `hello` shared between containers; disk-backed, pod-lifetime |
| Step 2 — hostPath | the node's hostname, and the node it came from |
| Step 3 — configMap/secret | `hi`, `s3cret`, both mounts `tmpfs` |
| Step 4 — projected | both keys under one mount point |
| Step 5 — downwardAPI | the pod's labels and name as file contents |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `kubectl logs` needs `-c` | Multi-container pod: name the container, e.g. `-c reader`. |
| `reader` logs are empty | It started before `writer` wrote the file. `kubectl delete pod scratch` and re-apply, or check `-c writer`. |
| hostPath pod `Pending` | The path must exist on the chosen node; `type: Directory` requires it up front. |
| `projected` rejects the manifest | Inside `sources`, a Secret uses `name:` while a standalone `secret` volume uses `secretName:`. |
| downwardAPI labels file is empty | The pod has no labels — add them under `metadata.labels`. |
| ConfigMap file does not refresh | It was mounted with `subPath`, which pins content. Mount the directory instead. |

---

## What you learned
- emptyDir for scratch, hostPath for node files (risky).
- configMap/secret/projected mounts are tmpfs and auto-updating.
- downwardAPI exposes pod metadata to the app.
