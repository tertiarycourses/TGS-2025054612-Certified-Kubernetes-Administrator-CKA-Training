# Step 5 — Allow from another namespace

```bash
kubectl create ns trusted
kubectl label ns trusted purpose=trusted
kubectl -n trusted run remote --image=nicolaka/netshoot --command -- sleep 3600
kubectl -n trusted wait --for=condition=Ready pod/remote --timeout=60s

kubectl -n netpol patch networkpolicy allow-trusted --type=merge -p '{"spec":{"ingress":[{"from":[{"podSelector":{"matchLabels":{"role":"allowed"}}},{"namespaceSelector":{"matchLabels":{"purpose":"trusted"}}}],"ports":[{"protocol":"TCP","port":80}]}]}}'

kubectl -n netpol get networkpolicy allow-trusted -o jsonpath='{.spec.ingress[0].from}{"\n"}'
kubectl -n trusted exec remote -- curl -s -o /dev/null -w "%{http_code}\n" http://server.netpol.svc.cluster.local
kubectl -n netpol exec client-bad -- curl -s --max-time 3 http://server || echo "client-bad still BLOCKED"
```

**Expected result:** `200` from the `trusted` namespace, while `client-bad` in `netpol`
stays blocked.

> **Two list items, not one.** `from:` holds a list, and separate items are **OR**ed:
> "pods labelled `role=allowed`" *or* "anything in a namespace labelled
> `purpose=trusted`". Put `podSelector` and `namespaceSelector` under a **single** item and
> the meaning changes to AND — pods with that label *inside* that namespace. That is the
> most commonly mis-written NetworkPolicy in the exam.
>
> Use JSON for `--type=merge`: a YAML patch string works only sometimes.
