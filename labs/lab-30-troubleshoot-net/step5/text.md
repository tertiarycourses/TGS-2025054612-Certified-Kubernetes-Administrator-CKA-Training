# Step 5 — The triage chain

When `curl <svc>` fails inside a pod:

```bash
# 1) Does DNS resolve?
kubectl exec probe -- nslookup web

# 2) Does the Service have endpoints?
kubectl get endpointslices -l kubernetes.io/service-name=web

# 3) Does the pod match the selector?
kubectl get pods --show-labels -l app=web

# 4) Does the targetPort match the container?
kubectl describe svc web | grep -E "Port|TargetPort"
kubectl get pod -l app=web -o jsonpath='{.items[0].spec.containers[0].ports[*].containerPort}{"\n"}'

# 5) Pod IP reachable from probe?
kubectl exec probe -- curl --max-time 3 http://$(kubectl get pod -l app=web -o jsonpath='{.items[0].status.podIP}'):80

# 6) NetworkPolicy blocking?
kubectl get networkpolicy -A

# 7) kube-proxy alive?
kubectl -n kube-system get pods -l k8s-app=kube-proxy
```
