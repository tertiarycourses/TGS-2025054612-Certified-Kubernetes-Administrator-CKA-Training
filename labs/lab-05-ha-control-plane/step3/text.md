# Step 3 — Why the endpoint must be inside the certificate

A VIP has an address of its own. Give yourself a name for it and try:

```bash
IP=$(hostname -I | awk '{print $1}')
echo "$IP k8s-vip" | sudo tee -a /etc/hosts
kubectl --server=https://k8s-vip:8443 get nodes
```

This fails on purpose:

```text
x509: certificate is valid for kubernetes, kubernetes.default, …, 172.30.1.2, not k8s-vip
```

TLS rejected the name because it is not in the certificate's SANs. Confirm what is:

```bash
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text \
  | grep -A1 "Subject Alternative Name"
```

No `k8s-vip`. That is precisely what `--control-plane-endpoint` adds — Step 4.
