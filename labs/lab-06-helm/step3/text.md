# Step 3 — Install a chart

```bash
helm install web podinfo/podinfo \
  --namespace web --create-namespace \
  --set replicaCount=2 \
  --set ui.message="hello from revision 1"
```

`web` is the **release name** — this installation's identity in the cluster. The same chart
can be installed many times under different release names.

```bash
helm -n web list
kubectl -n web get deploy,pod,svc
kubectl -n web rollout status deploy/web-podinfo --timeout=120s
```

**Expected result:** `helm list` shows release `web`, `REVISION 1`, status `deployed`; the
Deployment reports `2/2` ready. On a 1-CPU node the pods may take a minute.

See the value you set actually reach the application:

```bash
kubectl -n web port-forward svc/web-podinfo 9898:9898 > /dev/null 2>&1 &
sleep 3
curl -s http://localhost:9898/api/info | head -c 200; echo
kill %1
```

**Expected result:** JSON containing `"message": "hello from revision 1"`.
