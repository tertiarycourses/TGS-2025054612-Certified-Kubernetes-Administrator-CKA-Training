# Step 4 — projected (combine many sources)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: projected-demo }
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh","-c","ls -la /proj; cat /proj/greeting /proj/token; sleep 3600"]
    volumeMounts: [{ name: all, mountPath: /proj }]
  volumes:
  - name: all
    projected:
      sources:
      - configMap: { name: demo-cfg }
      - secret:    { name: demo-sec }
EOF
kubectl wait --for=condition=Ready pod/projected-demo --timeout=60s
kubectl logs projected-demo
```

**Expected result:** the listing shows **both** `greeting` and `token` under `/proj`,
followed by `hi` and `s3cret`.

One mount point, two sources — which is how a pod receives a ServiceAccount token, a CA
bundle and its namespace from a single `projected` volume (look at any pod's
`/var/run/secrets/kubernetes.io/serviceaccount`).
