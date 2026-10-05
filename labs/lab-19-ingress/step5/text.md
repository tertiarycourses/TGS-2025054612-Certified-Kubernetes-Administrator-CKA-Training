# Step 5 — Add TLS

```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
  -keyout tls.key -out tls.crt -subj "/CN=app1.local"
kubectl create secret tls app1-tls --cert=tls.crt --key=tls.key

kubectl patch ingress demo --type=merge \
  -p '{"spec":{"tls":[{"hosts":["app1.local"],"secretName":"app1-tls"}]}}'

HTTPS=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
curl -sk -H "Host: app1.local" https://localhost:$HTTPS
curl -sv -k -H "Host: app1.local" https://localhost:$HTTPS 2>&1 | grep -E "subject:|issuer:"
```

**Expected result:** `hello from app1` over HTTPS, and the certificate's subject is
`CN=app1.local` — your Secret, served by the controller. `-k` is required because the
certificate is self-signed.

> **Use JSON for `--type=merge`.** A YAML patch string works only sometimes; JSON always
> does, and it is what the API expects. The controller watches the Secret, so TLS starts
> working within a second or two of the patch — no restart.
