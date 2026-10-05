# Step 5 — Docker-registry Secret (private image pull)

```bash
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=demo \
  --docker-password=demo123 \
  --docker-email=demo@example.com
kubectl get secret regcred -o jsonpath='{.type}{"\n"}'
kubectl get secret regcred -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d; echo
```

**Expected result:** type `kubernetes.io/dockerconfigjson`, and the decoded value is a JSON
document containing the server, username and a base64 `auth` field. These credentials are
fake, so no pull will succeed with them — the point is the shape of the object.

Reference from a pod:

```yaml
spec:
  imagePullSecrets:
  - name: regcred
```
