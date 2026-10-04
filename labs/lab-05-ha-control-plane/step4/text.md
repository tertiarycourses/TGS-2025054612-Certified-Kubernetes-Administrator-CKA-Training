# Step 4 — Bootstrap the HA way, and join the worker through the LB

The load balancer must be running **before** `kubeadm init`, because kubeadm health-checks
the API through the endpoint you give it. HAProxy is up from Step 2.

On **node01** — teach it the VIP name, then reset:

```bash
echo "<CONTROLPLANE_IP> k8s-vip" | sudo tee -a /etc/hosts
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/etcd /etc/cni/net.d $HOME/.kube
sudo systemctl restart containerd
```

On **controlplane**:

```bash
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/etcd /etc/cni/net.d $HOME/.kube
sudo systemctl restart containerd
sudo systemctl restart haproxy

sudo kubeadm init \
  --control-plane-endpoint "k8s-vip:8443" \
  --upload-certs \
  --pod-network-cidr=192.168.0.0/16 \
  --ignore-preflight-errors=NumCPU

mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'; echo
kubectl get nodes
```

The server reads `https://k8s-vip:8443`, so every call goes through HAProxy. `init` printed
two join commands — use the **worker** one on node01; it already points at the endpoint.

`k8s-vip` is now in the certificate:

```bash
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text \
  | grep -A1 "Subject Alternative Name"
```
