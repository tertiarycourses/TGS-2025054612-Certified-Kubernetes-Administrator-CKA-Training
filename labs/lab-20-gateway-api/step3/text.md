# Step 3 — Deploy a backend

```bash
kubectl create deployment echo --image=hashicorp/http-echo:1.0 --port=5678 -- -text="gateway works"
kubectl expose deploy echo --port=80 --target-port=5678
kubectl rollout status deploy/echo --timeout=180s
kubectl get endpointslices -l kubernetes.io/service-name=echo \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]} ready={.conditions.ready}{"\n"}{end}'
```

**Expected result:** `deployment "echo" successfully rolled out`, and one endpoint address
with `ready=true`.

**Do not skip the wait.** A Gateway can only route to a *ready* endpoint. Curl too early
and you get `503 Service Temporarily Unavailable` from the data plane — the route is fine,
there is simply nothing healthy behind it. Confirm the backend works before involving the
Gateway at all:

```bash
kubectl run probe --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- http://echo
```

**Expected result:** `gateway works` — printed by the backend itself. Now any failure in
Step 6 belongs to the Gateway, not the app.

> `--target-port=5678` matters: `http-echo` listens on 5678 while the Service publishes 80.
> A mismatch here is the other common cause of a 503. The image is pinned to `:1.0` rather
> than `latest` so the lab behaves the same every time; its entrypoint is `/http-echo` and
> it runs as non-root user `65532`, which is why the `-text=` value is passed as an
> **argument**.

If the rollout times out with `0 of 1 updated replicas are available` and the endpoint shows `ready=false`, the container never started. Read the events — they name the cause:

```bash
kubectl get pods -l app=echo -o wide
kubectl describe pod -l app=echo | sed -n '/Events/,$p'
kubectl logs -l app=echo --tail=20
```

| Status | Cause |
|---|---|
| `ErrImagePull` / `ImagePullBackOff` with `toomanyrequests` | Docker Hub is rate-limiting the playground's shared IP. Wait and retry, or use the fallback below. |
| `ImagePullBackOff` with `no such host` | The node has no registry access. |
| `CrashLoopBackOff` | The container started and exited — `kubectl logs` shows why. |
| `ContainerCreating` for minutes | The pull is simply slow on a 1-CPU node; wait. |

**Fallback that needs no new pull.** `nginx` is already on both nodes from earlier labs, so it always works — the routing lesson is identical, you just get nginx's welcome page instead of the echo text:

```bash
kubectl delete deploy echo
kubectl create deployment echo --image=nginx --port=80
kubectl expose deploy echo --port=80 --target-port=80 --name=echo
kubectl rollout status deploy/echo --timeout=180s
```

Delete the old Service first if its `targetPort` no longer matches: `kubectl delete svc echo`.
