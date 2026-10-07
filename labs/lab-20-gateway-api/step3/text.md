# Step 3 — Deploy a backend

```bash
kubectl create deployment echo --image=hashicorp/http-echo --port=5678 -- -text="gateway works"
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
> A mismatch here is the other common cause of a 503.
