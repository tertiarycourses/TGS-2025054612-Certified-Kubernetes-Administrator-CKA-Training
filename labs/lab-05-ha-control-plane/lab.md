# Lab 5 — Highly-Available Control Plane

A real HA control plane needs three machines with 2 CPUs each. The free KillerCoda
environment gives you two 1-CPU nodes, so this lab does **not** pretend to build one.
Instead you build every piece of HA that *is* reproducible on one control plane, and
every step ends in a result you can check:

- the load balancer that fronts the apiserver, running for real on port **8443**;
- the `--control-plane-endpoint` bootstrap that makes a cluster *joinable* by more
  control planes later — including the certificate-key join command;
- etcd membership and the quorum arithmetic that decides how many nodes you need.

**Lab environment:** [two-node playground](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node) —
Tab 1 is **controlplane**, Tab 2 is **node01**. A cluster is already running; Step 4
rebuilds it deliberately.

> **Prerequisite:** a working cluster from Lab 2. Check with `kubectl get nodes` before
> you start.

---

## What you must be able to show

| Outcome | How you prove it |
|---|---|
| Why HA needs odd numbers | the quorum table in Step 1, and `etcdctl member list` |
| Your cluster is **not** HA today | `controlPlaneEndpoint` is absent from `kubeadm-config` |
| A load balancer can front the apiserver | `kubectl --server=https://<ip>:8443 get nodes` works through HAProxy |
| Why the endpoint must be in the certificate | the `x509: certificate is valid for …, not k8s-vip` error in Step 3, gone after Step 4 |
| An HA-shaped cluster | `kubectl config view` shows `server: https://k8s-vip:8443`, and the worker joined through it |
| How control plane #2 would join | a real `kubeadm join … --control-plane --certificate-key …` command |

---

## Step 1 — The topology, and what you actually have

The standard layout is **stacked etcd**: each control-plane node runs an apiserver *and*
an etcd member, behind one load-balanced address.

```
                      clients: kubectl, kubelets
                                  │
                        VIP / load balancer :6443
                                  │
            ┌─────────────────────┼─────────────────────┐
            ▼                     ▼                     ▼
          cp-1                  cp-2                  cp-3     ← apiserver + etcd member
            │                     │                     │
            └─────────────────────┼─────────────────────┘
                                  ▼
                               workers
```

Now measure your own cluster. How many control planes, and is an HA endpoint configured?

```bash
kubectl get nodes -l node-role.kubernetes.io/control-plane
kubectl -n kube-system get cm kubeadm-config -o yaml | grep -i controlPlaneEndpoint || \
  echo "no controlPlaneEndpoint: this cluster is NOT HA-ready"
```

**Expected result:** one control-plane node, and no `controlPlaneEndpoint`. A cluster
bootstrapped without that flag bakes the node's own IP into every kubeconfig and
certificate, so you cannot put a load balancer in front of it later without reissuing
certificates. That single fact is the whole reason the flag exists.

Next, the etcd side:

```bash
NODE=$(hostname)
kubectl -n kube-system get pods -l component=etcd -o wide
kubectl -n kube-system exec etcd-$NODE -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list -w table
```

**Expected result:** exactly **one** member, named after your node. The etcd pod is
`etcd-<nodename>` — on this playground `etcd-controlplane` — so `$NODE` saves you
guessing.

| etcd members | Quorum needed | Failures tolerated |
|---|---|---|
| 1 | 1 | 0 |
| 2 | 2 | 0 |
| 3 | 2 | 1 |
| 5 | 3 | 2 |

Two members tolerate **no** failures, which is why HA control planes come in odd
numbers. Quorum is `(n/2)+1` rounded down plus one — lose quorum and etcd goes
read-only, so the cluster keeps serving existing pods but accepts no changes.

---

## Step 2 — Put a real load balancer in front of the apiserver

In production the LB listens on 6443 and forwards to three apiservers. Here the apiserver
already owns 6443 on this node, so HAProxy listens on **8443** and forwards to the one
apiserver it has. The data path is identical: TCP passthrough, no TLS termination.

On **controlplane**:

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
    # In a real HA cluster the other control planes are listed here too:
    # server cp-2 10.0.0.12:6443 check
    # server cp-3 10.0.0.13:6443 check
EOF
sudo systemctl restart haproxy
sudo systemctl is-active haproxy
sudo ss -lntp | grep 8443
```

**Expected result:** `active`, and HAProxy listening on `*:8443`.

> **Why not `bind *:6443`?** That is the apiserver's port on this very node. HAProxy would
> fail to start with `cannot bind socket`. The LB only owns 6443 when it runs on *separate*
> machines from the apiservers.

Now prove the API works *through* the load balancer. Your certificate already contains
this node's IP, so TLS verification passes:

```bash
IP=$(hostname -I | awk '{print $1}')
kubectl --server=https://$IP:8443 get nodes
```

**Expected result:** the normal node list. Traffic went kubectl → HAProxy:8443 →
apiserver:6443.

---

## Step 3 — Why the endpoint must be inside the certificate

A VIP is reached by a *name or address of its own*, not the node's. Give yourself one and
try it:

```bash
IP=$(hostname -I | awk '{print $1}')
echo "$IP k8s-vip" | sudo tee -a /etc/hosts
kubectl --server=https://k8s-vip:8443 get nodes
```

**Expected result — a deliberate failure:**

```text
Unable to connect to the server: tls: failed to verify certificate: x509:
certificate is valid for kubernetes, kubernetes.default, …, 172.30.1.2, not k8s-vip
```

The connection reached the apiserver; TLS rejected it because `k8s-vip` is not in the
certificate's Subject Alternative Names. Look at what *is*:

```bash
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text \
  | grep -A1 "Subject Alternative Name"
```

**Expected result:** `kubernetes`, `kubernetes.default`, …, the service IP and this node's
IP — and no `k8s-vip`. This is what `--control-plane-endpoint` fixes: it puts the shared
endpoint into the SANs and into every generated kubeconfig. Step 4 does it properly.

---

## Step 4 — Bootstrap the HA way, and join the worker through the LB

This rebuilds the cluster from Lab 2 so the endpoint can be baked in. The order matters:
**the load balancer must be up before `kubeadm init`**, because kubeadm health-checks the
API through the endpoint you give it. HAProxy is already running from Step 2.

First tell **node01** about the VIP name as well — it will join through it. On **node01**:

```bash
echo "<CONTROLPLANE_IP> k8s-vip" | sudo tee -a /etc/hosts   # the IP from Step 3
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
```

- `--control-plane-endpoint` writes `k8s-vip:8443` into the certificates and kubeconfigs,
  so clients and future control planes all use the LB address.
- `--upload-certs` stores the PKI in a Secret for two hours so other control planes can
  join without copying files by hand.
- `--ignore-preflight-errors=NumCPU` is needed on this 1-CPU playground, as in Lab 2.

`init` prints **two** join commands: one with `--control-plane --certificate-key …`, one
for workers. Set up kubeconfig and verify the endpoint:

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'; echo
kubectl get nodes
```

**Expected result:** the server is `https://k8s-vip:8443` — every `kubectl` call now goes
through HAProxy — and the node is listed (`NotReady` until a CNI is installed, as in
Lab 2). The SAN check from Step 3 now includes `k8s-vip`:

```bash
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text \
  | grep -A1 "Subject Alternative Name"
```

Join the worker **through the endpoint** — paste the real worker join command `init`
printed (it already points at `k8s-vip:8443`). On **node01**:

```bash
sudo kubeadm join k8s-vip:8443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

**Expected result:** `This node has joined the cluster`, and on controlplane
`kubectl get nodes` lists both. The worker's kubelet now talks to the LB address, so in a
real cluster it would survive the loss of any single control plane.

---

## Step 5 — The control-plane join command, for real

You cannot run it here — a second control plane needs its own VM with 2 CPUs — but you can
generate the exact command, which is what the exam asks for. The certificate key uploaded
by `--upload-certs` expires after two hours; regenerate it any time:

```bash
sudo kubeadm init phase upload-certs --upload-certs
kubeadm token create --print-join-command
```

**Expected result:** a certificate key, and a worker join command. A control plane joins
with both pieces together:

```bash
sudo kubeadm join k8s-vip:8443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane --certificate-key <key-from-upload-certs>
```

That node would start its own apiserver, register a **second etcd member**, and be added
to the HAProxy backend list. With three control planes, `etcdctl member list` shows three
voting members and the quorum table in Step 1 says you can lose one.

---

## Reference — keepalived for a floating VIP

`/etc/hosts` stands in for a VIP in this lab because KillerCoda gives you no spare routable
address and VRRP between nodes is usually blocked. On real hardware, keepalived moves one
IP between control planes. Note the interface is detected, not assumed — it is rarely
`eth0` on cloud images:

```bash
IFACE=$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')
echo "default interface: $IFACE"
```

```text
vrrp_instance VI_1 {
    state MASTER            # BACKUP on the other nodes
    interface <IFACE>       # from the command above
    virtual_router_id 51
    priority 101            # lower on the BACKUP nodes
    advert_int 1
    authentication { auth_type PASS auth_pass changeme }
    virtual_ipaddress { 10.0.0.10 }    # your real spare IP
}
```

The HAProxy config from Step 2 is already the production shape: uncomment the `cp-2` and
`cp-3` lines, change the frontend to `bind *:6443`, and run it on machines separate from
the apiservers.

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — control planes | one node; no `controlPlaneEndpoint`; one etcd member named after the node |
| Step 2 — HAProxy | `active`, listening on `*:8443`; `kubectl --server=https://<ip>:8443 get nodes` works |
| Step 3 — SAN failure | `x509: certificate is valid for …, not k8s-vip`; `k8s-vip` absent from the SAN list |
| Step 4 — HA bootstrap | `server: https://k8s-vip:8443`; `k8s-vip` now in the SANs; both nodes listed |
| Step 5 — join command | a certificate key plus a join command containing `--control-plane` |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `haproxy` fails with `cannot bind socket` | Something already owns the port. Keep the frontend on 8443 on this node. |
| `kubectl --server=https://<ip>:8443` hangs | HAProxy is down or the backend is wrong: `sudo systemctl status haproxy`, `sudo ss -lntp | grep 8443`. |
| `x509: … not k8s-vip` after Step 4 | The `/etc/hosts` entry or `--control-plane-endpoint` was missing at `init`. Re-run Step 4. |
| `kubeadm init` reports ports in use or existing manifests | The reset did not finish. Re-run the reset block on that node (see Lab 2 Step 0). |
| Worker join fails with `k8s-vip: no such host` | node01 has no `/etc/hosts` entry for the VIP name. Add it, then rejoin. |
| `etcd-cp-1 not found` | The pod is `etcd-<nodename>`; use `NODE=$(hostname)` as in Step 1. |

---

## What you learned
- The stacked-etcd topology, and why control planes come in odd numbers.
- That `--control-plane-endpoint` must be set **at bootstrap**: it writes the shared
  address into the certificates and kubeconfigs, which is why adding a load balancer
  afterwards means reissuing certificates.
- How a TCP-passthrough load balancer fronts the apiserver, and why it binds 6443 only on
  separate machines.
- How `--upload-certs` and `--certificate-key` let another control plane join without
  copying PKI by hand.
- How to read etcd membership and compute quorum.
