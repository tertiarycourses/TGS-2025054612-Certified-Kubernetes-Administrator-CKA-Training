# Step 2 — Deploy two backends

```bash
kubectl create deployment app1 --image=hashicorp/http-echo --port=5678 -- \
  -text="hello from app1"
kubectl create deployment app2 --image=hashicorp/http-echo --port=5678 -- \
  -text="hello from app2"
kubectl expose deploy app1 --port=80 --target-port=5678
kubectl expose deploy app2 --port=80 --target-port=5678
kubectl get pods -l 'app in (app1,app2)'
kubectl run probe --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- http://app1
```

**Expected result:** both pods Running, and the probe prints `hello from app1` — the
backends work *before* any Ingress exists, so a later failure is the Ingress, not the app.

> `--target-port=5678` matters: `http-echo` listens on 5678 while the Service publishes 80.
> A mismatch here is the most common "502 from the Ingress" cause.
