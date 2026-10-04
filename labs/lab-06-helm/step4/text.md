# Step 4 — Override values with a file

`--set` is fine for one or two keys; real deployments keep a values file under version
control. Create one:

```bash
cat > values.yaml <<'EOF'
replicaCount: 3
ui:
  message: "hello from revision 2"
service:
  type: ClusterIP
EOF
helm upgrade web podinfo/podinfo -n web -f values.yaml
```

```bash
kubectl -n web get deploy web-podinfo
helm -n web history web
```

**Expected result:** the Deployment scales to `3/3`, and `history` lists **two** revisions —
revision 1 `superseded`, revision 2 `deployed`.

> **`--set` and `-f` do not merge across commands.** Each `helm upgrade` computes the
> release from the chart defaults plus *only* the overrides given in that command. The
> `--set ui.message` from Step 3 is gone unless the values file repeats it — which is why
> revision 2 must set the message again. Use `helm get values web -n web` to see exactly
> what a release is currently using.
