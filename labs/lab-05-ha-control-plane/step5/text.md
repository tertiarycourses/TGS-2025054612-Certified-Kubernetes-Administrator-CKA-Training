# Step 5 — The control-plane join command, for real

A second control plane needs its own VM with 2 CPUs, so you cannot run this here — but
generating the command is the exam skill. The key from `--upload-certs` expires after two
hours; regenerate it any time:

```bash
sudo kubeadm init phase upload-certs --upload-certs
kubeadm token create --print-join-command
```

Combine both pieces:

```bash
sudo kubeadm join k8s-vip:8443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane --certificate-key <key-from-upload-certs>
```

That node starts its own apiserver, registers a second etcd member, and is added to the
HAProxy backend list. Three control planes means three voting members — and by the quorum
table in Step 1, one can fail.
