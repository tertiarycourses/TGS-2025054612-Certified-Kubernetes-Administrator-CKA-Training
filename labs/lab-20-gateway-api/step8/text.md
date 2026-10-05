# Step 8 — Cleanup

```bash
kubectl delete httproute echo-route
kubectl delete gateway web
kubectl -n default get deploy,svc
kubectl delete svc echo && kubectl delete deploy echo
```

**Expected result:** deleting the **Gateway** also removes the nginx Deployment and Service
it provisioned — they were owned by it, so garbage collection takes them. Only `echo`
remains until you delete it.

Remove the controller and the CRDs if you are done with Gateway API:

```bash
kubectl delete -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.7.2/deploy/nodeport/deploy.yaml --ignore-not-found
kubectl delete -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.7.2/deploy/crds.yaml --ignore-not-found
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml --ignore-not-found
```

**Expected result:** deleting the Gateway API CRDs removes every Gateway and HTTPRoute in
the cluster — CRD deletion is cluster-wide and irreversible.
