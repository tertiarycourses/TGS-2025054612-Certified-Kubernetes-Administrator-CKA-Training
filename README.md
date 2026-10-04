# TGS-2025054612 — Certified Kubernetes Administrator (CKA) Hands-On Labs

> **Course:** WSQ — Certified Kubernetes Administrator (CKA) Training
> **Course Code:** TGS-2025054612
> **Register here:** https://www.tertiarycourses.com.sg/wsq-certified-kubernetes-administrator-cka-training.html

These are the official hands-on lab exercises for the WSQ Certified Kubernetes Administrator (CKA) Training course delivered by [**Tertiary Infotech Academy Pte Ltd**](https://www.tertiarycourses.com.sg/).

A complete set of **31 step-by-step labs** aligned to the CNCF **CKA v1.35** exam objectives. Labs 1–5 run on the Killercoda **kubeadm** playground (two empty Ubuntu nodes); all other labs run on the free **Killercoda Kubernetes Playground** (https://killercoda.com/playgrounds/scenario/kubernetes) — no local install required.

---

## How to use

1. Open Killercoda in your browser:
   - Standard cluster: https://killercoda.com/playgrounds/scenario/kubernetes
   - kubeadm scenario (Labs 1–5): https://killercoda.com/playgrounds/scenario/kubeadm
2. Pick a lab from the list below and follow the steps in order.
3. At the start of every session run the exam-speed aliases:
   ```bash
   alias k=kubectl
   export do="--dry-run=client -o yaml"
   source <(kubectl completion bash)
   complete -o default -F __start_kubectl k
   ```
4. See [labs/tools.md](labs/tools.md) for every free tool used (with install commands and download links).

---

## Lab catalogue

### Domain 1 — Cluster Architecture, Installation and Configuration (25%)

| Lab | Topic | What you practise |
|-----|-------|-------------------|
| [01](labs/lab-01-kubeadm-prereqs/) | kubeadm Prerequisites | kernel modules, sysctls, containerd (SystemdCgroup), pkgs.k8s.io |
| [02](labs/lab-02-kubeadm-bootstrap/) | Cluster Bootstrap | `kubeadm init`, kubeconfig, PKI, etcd, worker `join` |
| [03](labs/lab-03-cni-calico/) | Calico CNI | tigera-operator, pod CIDR, cross-node pod ping |
| [04](labs/lab-04-cluster-upgrade/) | Cluster Upgrade | `kubeadm upgrade`, drain/uncordon, `apt-mark hold` |
| [05](labs/lab-05-ha-control-plane/) | HA Overview and etcd Backup/Restore | quorum, `--control-plane-endpoint`, `etcdctl snapshot save`/`restore` |
| [06](labs/lab-06-helm/) | Helm | `helm repo add`, `install`, `upgrade`, `rollback`, `--set`, `values.yaml` |
| [07](labs/lab-07-kustomize/) | Kustomize | base + overlays, `namePrefix`, `images`, `patches`, `kubectl apply -k` |
| [08](labs/lab-08-rbac/) | RBAC | Role, ClusterRole, RoleBinding, ServiceAccount, `kubectl auth can-i` |

### Domain 2 — Workloads and Scheduling (15%)

| Lab | Topic | What you practise |
|-----|-------|-------------------|
| [09](labs/lab-09-crds-operators/) | CRDs and Operators | `kubectl api-resources`, schema validation, cert-manager Operator |
| [10](labs/lab-10-extension-interfaces/) | CRI / CNI / CSI | `crictl`, `/etc/cni/net.d`, `kubectl get csidrivers` |
| [11](labs/lab-11-deployments-rollout/) | Deployments and Rollouts | rolling update, bad image recovery, `rollout undo`, pause/resume |
| [12](labs/lab-12-configmaps/) | ConfigMaps | `--from-literal`, `envFrom`, volume mount, live-update semantics |
| [13](labs/lab-13-secrets/) | Secrets | generic/tls/docker-registry, env inject, tmpfs mount, `defaultMode 0400` |
| [14](labs/lab-14-hpa/) | HPA v2 | `metrics-server`, CPU target, load test, watch scale |
| [15](labs/lab-15-self-healing/) | Self-Healing | liveness/readiness probes, ReplicaSet, DaemonSet, StatefulSet |
| [16](labs/lab-16-scheduling/) | Scheduling | `nodeSelector`, `nodeAffinity`, taints/tolerations, resource requests/limits |

### Domain 3 — Services and Networking (20%)

| Lab | Topic | What you practise |
|-----|-------|-------------------|
| [17](labs/lab-17-pod-connectivity/) | Pod Connectivity | flat pod network, `curl`, DNS discovery, `netshoot` |
| [18](labs/lab-18-service-types/) | Service Types | ClusterIP, NodePort, LoadBalancer (MetalLB), EndpointSlices, selector debug |
| [19](labs/lab-19-ingress/) | Ingress | ingress-nginx, host routing, path rules, TLS termination |
| [20](labs/lab-20-gateway-api/) | Gateway API | GatewayClass, Gateway, HTTPRoute (`gateway.networking.k8s.io/v1`) |
| [21](labs/lab-21-network-policies/) | NetworkPolicy | default-deny, pod/namespace selector, egress lockdown |
| [22](labs/lab-22-coredns/) | CoreDNS | Corefile inspection, headless services, stub zones, `nslookup` |

### Domain 4 — Storage (10%)

| Lab | Topic | What you practise |
|-----|-------|-------------------|
| [23](labs/lab-23-pv-pvc/) | PV and PVC | static provisioning, access modes, reclaim policy, `hostPath` |
| [24](labs/lab-24-storageclass/) | StorageClass | dynamic provisioning, default class, `volumeClaimTemplates` |
| [25](labs/lab-25-volume-types/) | Volume Types | `emptyDir`, `hostPath`, `projected`, `downwardAPI` |

### Domain 5 — Troubleshooting (30%)

| Lab | Topic | What you practise |
|-----|-------|-------------------|
| [26](labs/lab-26-troubleshoot-components/) | Cluster Components | static pods, `/etc/kubernetes/manifests/`, `crictl logs`, `journalctl` |
| [27](labs/lab-27-troubleshoot-nodes/) | Node Troubleshooting | `NotReady`, kubelet failure, cgroup mismatch, drain/uncordon |
| [28](labs/lab-28-logs-streams/) | Application Logs | `kubectl logs --previous`, multi-container, raw log files on disk |
| [29](labs/lab-29-monitoring/) | Cluster Monitoring | `kubectl top`, events timeline, `metrics-server` |
| [30](labs/lab-30-troubleshoot-net/) | Network Troubleshooting | DNS, selector debug, endpoints, CNI, NetworkPolicy |
| [31](labs/lab-31-troubleshoot-rbac-sched/) | RBAC & Scheduling | `403 Forbidden`, `kubectl auth can-i`, Pending pod, taint/toleration |

---

## Practicum Assessments

Hands-on summative assessments, one per training day:

| Assessment | Coverage | Time |
|------------|----------|------|
| [Practicum 1](labs/assessments/practicum-1/question.md) | Domain 1 — Cluster Architecture & Installation | 45 min |
| [Practicum 2](labs/assessments/practicum-2/question.md) | Domain 2 — Workloads & Scheduling | 45 min |
| [Practicum 3](labs/assessments/practicum-3/question.md) | Domains 3 & 4 — Networking & Storage | 45 min |
| [Practicum 4](labs/assessments/practicum-4/question.md) | Domain 5 + Final Mock (all domains) | 2 hr |

---

## Learner Guide

The full step-by-step Learner Guide (all 31 labs with commands, YAML and Test-it checks) is available in Markdown: [LEARNER GUIDE.md](LEARNER%20GUIDE.md).

---

## Courseware

The [`courseware/`](courseware/) folder holds the generated training deliverables:

| File | Description |
|------|-------------|
| [`Certified-Kubernetes-Administrator-CKA-v6.pptx`](courseware/Certified-Kubernetes-Administrator-CKA-v6.pptx) | Slide deck (289 slides, all 4 days) |
| [`Certified-Kubernetes-Administrator-CKA-v6.pdf`](courseware/Certified-Kubernetes-Administrator-CKA-v6.pdf) | PDF version of the slide deck |
| [`LG-Certified-Kubernetes-Administrator-CKA.docx`](courseware/LG-Certified-Kubernetes-Administrator-CKA.docx) | Learner Guide (Word) |
| [`LG-Certified-Kubernetes-Administrator-CKA.pdf`](courseware/LG-Certified-Kubernetes-Administrator-CKA.pdf) | Learner Guide (PDF) |
| [`LP-Certified-Kubernetes-Administrator-CKA.docx`](courseware/LP-Certified-Kubernetes-Administrator-CKA.docx) | Lesson Plan (Word) |
| [`LP-Certified-Kubernetes-Administrator-CKA.pdf`](courseware/LP-Certified-Kubernetes-Administrator-CKA.pdf) | Lesson Plan (PDF) |

---

## Reference

- [labs/README.md](labs/README.md) — Lab index grouped by domain with software requirements
- [labs/tools.md](labs/tools.md) — Complete list of free tools (Killercoda + external)
- [`references/`](references/) — Source reference material (previous-version CKA crash-course slide deck)
- Tertiary Infotech CKA Practice Exam: https://exams.tertiaryinfotech.com/practice-exams/linuxfoundation/linuxfoundation-cka
- CNCF CKA exam curriculum: https://github.com/cncf/curriculum
- Official CKA exam: https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/
