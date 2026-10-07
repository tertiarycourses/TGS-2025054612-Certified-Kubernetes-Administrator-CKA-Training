# Step 2 — Deploy two backends

```bash
kubectl create deployment app1 --image=hashicorp/http-echo:1.0 --port=5678 -- \
  -text="hello from app1"
kubectl create deployment app2 --image=hashicorp/http-echo:1.0 --port=5678 -- \
  -text="hello from app2"
kubectl rollout status deploy/app1 --timeout=180s
kubectl rollout status deploy/app2 --timeout=180s
kubectl expose deploy app1 --port=80 --target-port=5678
kubectl expose deploy app2 --port=80 --target-port=5678
kubectl get pods -l 'app in (app1,app2)'
kubectl run probe --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- http://app1
```

**Expected result:** both pods Running, and the probe prints `hello from app1` — the
backends work *before* any Ingress exists, so a later failure is the Ingress, not the app.

> `--target-port=5678` matters: `http-echo` listens on 5678 while the Service publishes 80.
> A mismatch here is the most common "502 from the Ingress" cause. The image is pinned to
> `:1.0` rather than `latest` so the lab behaves the same every time.

If the rollout times out with `0 of 1 updated replicas are available` and the endpoint shows `ready=false`, the container never started. Read the events — they name the cause:

```bash
kubectl get pods -l app=app1 -o wide
kubectl describe pod -l app=app1 | sed -n '/Events/,$p'
kubectl logs -l app=app1 --tail=20
```

| Status | Cause |
|---|---|
| `ErrImagePull` / `ImagePullBackOff` with `toomanyrequests` | Docker Hub is rate-limiting the playground's shared IP. Wait and retry, or use the fallback below. |
| `ImagePullBackOff` with `no such host` | The node has no registry access. |
| `CrashLoopBackOff` | The container started and exited — `kubectl logs` shows why. |
| `ContainerCreating` for minutes | The pull is simply slow on a 1-CPU node; wait. |

**Fallback that needs no new pull.** `nginx` is already on both nodes from earlier labs, so it always works — the routing lesson is identical, you just get nginx's welcome page instead of the echo text:

```bash
kubectl delete deploy app1
kubectl create deployment app1 --image=nginx --port=80
kubectl expose deploy app1 --port=80 --target-port=80 --name=app1
kubectl rollout status deploy/app1 --timeout=180s
```

Delete the old Service first if its `targetPort` no longer matches: `kubectl delete svc app1`.

> With nginx as the backend, expect its welcome page instead of `hello from app1` — the
> host-based routing in Step 4 is unchanged, which is the point of the step.
