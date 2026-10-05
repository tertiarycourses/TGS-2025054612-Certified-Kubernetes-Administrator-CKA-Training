# Step 3 — NodePort

```bash
kubectl expose deploy web --port=80 --type=NodePort --name=web-nodeport
kubectl get svc web-nodeport
PORT=$(kubectl get svc web-nodeport -o jsonpath='{.spec.ports[0].nodePort}')
echo "nodePort: $PORT"
curl -s http://localhost:$PORT | head -5
```

**Expected result:** a port in the **30000-32767** range, and nginx's HTML. The same port
answers on *every* node, including ones running none of the pods — kube-proxy forwards from
whichever node you hit:

```bash
NODE_IP=$(kubectl get node -o jsonpath='{.items[1].status.addresses[0].address}')
curl -s -o /dev/null -w "from %s: %%{http_code}\n" http://$NODE_IP:$PORT
```

**Expected result:** `200` from the other node too. A NodePort is a superset of ClusterIP —
it keeps the ClusterIP and adds the host port.
