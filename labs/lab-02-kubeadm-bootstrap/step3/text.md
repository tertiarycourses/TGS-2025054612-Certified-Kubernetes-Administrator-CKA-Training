# Step 3 — Join the worker

Switch to your **node01** tab (or run `ssh node01` from the control plane).

**Reset node01 first.** It was part of the cluster the playground pre-built, so the join
is refused while its old kubelet config and CA sit on disk:

```text
[ERROR FileAvailable--etc-kubernetes-kubelet.conf]: /etc/kubernetes/kubelet.conf already exists
[ERROR FileAvailable--etc-kubernetes-pki-ca.crt]: /etc/kubernetes/pki/ca.crt already exists
[ERROR Port-10250]: Port 10250 is in use
```

```bash
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/etcd /etc/cni/net.d $HOME/.kube
sudo systemctl restart containerd
```

Now join the worker. **Do not copy the template below** - it only shows the shape of the
command. Paste the real `kubeadm join` line that `kubeadm init` printed at the end of
Step 1, with your own IP, token and hash. Pasting the placeholders fails with
`bash: syntax error near unexpected token 'newline'`, because the shell reads `<` and `>`
as redirections:

```bash
sudo kubeadm join <CONTROLPLANE_IP>:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

Lost that line, or is the token past its 24 h TTL? Print a fresh one **on the control
plane** and run the command it gives you on node01:

```bash
kubeadm token create --print-join-command
```

A successful join ends with `This node has joined the cluster`.
