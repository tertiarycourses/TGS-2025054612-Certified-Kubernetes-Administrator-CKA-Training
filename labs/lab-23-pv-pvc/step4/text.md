# Step 4 — Mount in a Pod

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: web }
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - { name: data, mountPath: /usr/share/nginx/html }
  volumes:
  - name: data
    persistentVolumeClaim: { claimName: pvc-host }
EOF
kubectl wait --for=condition=Ready pod/web --timeout=60s
kubectl get pod web -o wide
kubectl exec web -- curl -s localhost
```

**Expected result:** `hello from host` — the file you wrote on the node in Step 1, served
by nginx from the mounted volume. The `NODE` column must show the node from Step 1.

If you get nginx's default welcome page instead, the pod is running on a different node
from the directory — check the node affinity in Step 2.
