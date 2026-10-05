# Practicum 3 — Services & Networking + Storage (Domains 3 & 4)

> **Day 3 assessment  ·  Time allowed: 45 minutes**  
> Platform: [Killercoda Kubernetes Playground](https://killercoda.com/playgrounds/scenario/kubernetes)

---

## Task 1 — Ingress with TLS (10 pts)

1. Install the `ingress-nginx` controller from the pinned bare-metal manifest, which creates a NodePort Service:

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/baremetal/deploy.yaml
   kubectl -n ingress-nginx wait --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=300s
   ```
2. Generate a self-signed TLS certificate for `demo.cka.local` and create a `kubernetes.io/tls` Secret named `demo-tls`.
3. Create a Deployment `demo-app` (nginx:1.25, 2 replicas) and a ClusterIP Service on port 80.
4. Create an **Ingress** that routes `demo.cka.local/` to `demo-app:80` using TLS secret `demo-tls`.

**Verify:** the request returns the nginx welcome page. There is no DNS for `demo.cka.local`, so point curl at the controller's HTTPS NodePort explicitly:

```bash
HTTPS=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
curl -k --resolve demo.cka.local:$HTTPS:127.0.0.1 https://demo.cka.local:$HTTPS
```

---

## Task 2 — NetworkPolicy (8 pts)

In namespace `isolated`:
1. Deploy two pods: `frontend` (label `role=frontend`) and `backend` (label `role=backend`).
2. Apply a **default-deny** NetworkPolicy for all ingress in the namespace.
3. Apply a **selective allow** policy so only pods with label `role=frontend` can reach `backend` on port **8080**.

**Verify:** `kubectl exec frontend -- curl backend:8080` succeeds; exec from another pod without the label fails.

---

## Task 3 — PersistentVolume and PVC (7 pts)

1. Create a **PersistentVolume** `data-pv` with `capacity: 1Gi`, `accessModes: ReadWriteOnce`, `hostPath: /data/cka`, and `reclaimPolicy: Retain`.

   > `hostPath` reads one specific node's disk. Create `/data/cka` on the node that will run the pod (the worker, since the control plane is tainted) and give the PV a matching `spec.nodeAffinity` on `kubernetes.io/hostname` — otherwise the pod may mount an empty directory on the wrong node. See Lab 23.
2. Create a **PersistentVolumeClaim** `data-pvc` requesting `1Gi` with `ReadWriteOnce`.
3. Create a Pod `data-pod` that mounts `data-pvc` at `/data`.
4. Write a file: `kubectl exec data-pod -- sh -c 'echo hello > /data/test.txt'`.

**Verify:** `kubectl exec data-pod -- cat /data/test.txt` returns `hello`.

---

## Task 4 — StorageClass and dynamic provisioning (5 pts)

1. Inspect the default StorageClass: `kubectl get sc`.
2. Create a PVC `dynamic-pvc` with `storageClassName: standard` (or the default class), `1Gi`, `ReadWriteOnce`.
3. Wait for it to bind: `kubectl get pvc dynamic-pvc`.

**Verify:** PVC shows `STATUS: Bound` within 30 seconds.
