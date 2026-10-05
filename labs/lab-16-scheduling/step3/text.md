# Step 3 — Node affinity (soft preference)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: affinity-pod }
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - { key: tier, operator: In, values: [frontend] }
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 50
        preference:
          matchExpressions:
          - { key: disktype, operator: In, values: [ssd] }
  containers:
  - { name: app, image: nginx }
EOF
kubectl get pod affinity-pod -o wide
```

**Expected result:** `Running` on `$NODE`, which satisfies the required `tier=frontend`
rule and also happens to match the preferred `disktype=ssd` hint. Expect
`ContainerCreating` for the first few seconds — the `NODE` column is already populated,
which is the part that matters: the scheduler has decided.

`required…` behaves like `nodeSelector` but with richer operators (`In`, `NotIn`, `Exists`,
`Gt`, `Lt`). `preferred…` only ranks the candidates — if nothing matches, the pod still
schedules. That is the entire difference, and it is examinable.
