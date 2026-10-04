# Step 2 — Put a real load balancer in front of the apiserver

The apiserver already owns 6443 on this node, so HAProxy listens on **8443** and forwards
to it. TCP passthrough, no TLS termination — the same data path as production.

```bash
sudo apt update && sudo apt install -y haproxy
sudo tee /etc/haproxy/haproxy.cfg > /dev/null <<'EOF'
global
    daemon
defaults
    mode    tcp
    timeout connect 5s
    timeout client  30s
    timeout server  30s

frontend kube-apiserver
    bind *:8443
    default_backend kube-apiservers

backend kube-apiservers
    option tcp-check
    balance roundrobin
    server cp-1 127.0.0.1:6443 check
    # Real HA clusters list the other control planes here as well.
EOF
sudo systemctl restart haproxy
sudo systemctl is-active haproxy
sudo ss -lntp | grep 8443
```

`bind *:6443` would fail here with `cannot bind socket`: that is the apiserver's port. The
LB owns 6443 only when it runs on separate machines.

Reach the API through the load balancer — your node's IP is already in the certificate:

```bash
IP=$(hostname -I | awk '{print $1}')
kubectl --server=https://$IP:8443 get nodes
```
