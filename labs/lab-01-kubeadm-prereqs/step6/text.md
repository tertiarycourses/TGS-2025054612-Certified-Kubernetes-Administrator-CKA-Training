# Step 6 — Install crictl, then verify

`crictl` is the CRI debug client, and it is **not** installed by containerd or kubeadm — on
this playground it is missing entirely (`crictl: command not found`). Labs 5, 10, 26 and 27
depend on it, because it is the only way to inspect containers when the API server is down.

```bash
sudo apt-get update -qq && sudo apt-get install -y cri-tools
crictl --runtime-endpoint unix:///run/containerd/containerd.sock version
```

**Expected result:** `crictl` prints its version plus the runtime's
(`RuntimeName: containerd`).

`cri-tools` is published in the same `pkgs.k8s.io` repository as `kubeadm`, so the apt
source from Step 5 already covers it. If apt cannot find the package, take the binary from
the release instead:

```bash
VER=v1.37.0
curl -sL "https://github.com/kubernetes-sigs/cri-tools/releases/download/$VER/crictl-$VER-linux-amd64.tar.gz" \
  | sudo tar -xz -C /usr/local/bin crictl
crictl --version
```

> Set the endpoint once so you can drop the flag everywhere else:
>
> ```bash
> sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock
> ```
>
> Without it, newer `crictl` still works but warns on every call. There is always a
> fallback that needs no install, because it ships with containerd itself:
> `sudo ctr -n k8s.io containers ls`.

Now verify the whole set:

```bash
kubeadm version
kubectl version --client
systemctl is-active containerd
sudo crictl ps | head
```

You should see the `kubeadm` version you noted in Step 0 (for example `v1.37.1`), `containerd` active, and `crictl` reporting the runtime version.

---

> ✅ **Test it:** Both tabs show `kubeadm version` returning the version you noted in Step 0, `containerd` is active, and `kubectl version --client` works — the nodes are ready for `kubeadm init` in Lab 2.
