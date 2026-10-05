# Step 4 — TLS Secret

```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
  -keyout tls.key -out tls.crt -subj "/CN=demo.local"
kubectl create secret tls demo-tls --cert=tls.crt --key=tls.key
kubectl get secret demo-tls -o jsonpath='{.type}{"\n"}'
kubectl get secret demo-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject
```

**Expected result:** type `kubernetes.io/tls`, and the certificate's subject is
`CN = demo.local`. A `tls` Secret must contain exactly the keys `tls.crt` and `tls.key` —
Ingress and Gateway API controllers look for those names.

TLS Secrets are used by Ingress, Gateway API, and webhook servers (Lab 19, 20).
