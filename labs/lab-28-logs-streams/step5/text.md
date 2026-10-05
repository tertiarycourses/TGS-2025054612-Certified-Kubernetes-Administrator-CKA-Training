# Step 5 — Multi-pod tail with stern (optional)

```bash
curl -sL https://github.com/stern/stern/releases/download/v1.34.0/stern_1.34.0_linux_amd64.tar.gz \
  | sudo tar -xz -C /usr/local/bin stern
stern --version
stern chatty --tail 5
```

**Expected result:** `stern` prints its version, then follows the `chatty` pods with each
line prefixed by pod and container name. Ctrl-C to stop.

`stern` takes a **regex** over pod names and follows across pods, containers and namespaces
at once — `kubectl logs` needs an exact pod. Try `stern . -n kube-system --tail 1` to watch
the whole control plane.

> Installed straight from the release tarball and pinned: the previous `go install` path
> needs a Go toolchain the playground does not have, and an unpinned version has changed
> flags between course runs.
