# CKA v1.35 Lab Index — 2026 Edition

Hands-on labs for the **Certified Kubernetes Administrator (CKA)** exam. All 31 labs run on the free Killercoda Kubernetes Playground — no local installation required.

**Standard lab environment:** https://killercoda.com/playgrounds/scenario/kubernetes
**kubeadm scenarios (Labs 1–5):** https://killercoda.com/playgrounds/scenario/kubeadm
**Alternative:** https://labs.play-with-k8s.com

**First thing to run on every session:**
```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
source <(kubectl completion bash)
complete -o default -F __start_kubectl k
```

---

## Domain 1 — Cluster Architecture, Installation and Configuration (25%)

| Lab | Title | Key Skill |
|-----|-------|-----------|
| [Lab 01](lab-01-kubeadm-prereqs/) | kubeadm Prerequisites and Container Runtime | kernel modules, sysctls, containerd, pkgs.k8s.io |
| [Lab 02](lab-02-kubeadm-bootstrap/) | Bootstrap a Cluster with kubeadm | `kubeadm init`, kubeconfig, PKI, worker join |
| [Lab 03](lab-03-cni-calico/) | Install Calico CNI | tigera-operator, pod CIDR, cross-node ping |
| [Lab 04](lab-04-cluster-upgrade/) | Cluster Upgrade: v1.34 → v1.35 | `kubeadm upgrade`, drain, uncordon, package hold |
| [Lab 05](lab-05-ha-control-plane/) | HA Overview and etcd Backup/Restore | quorum, `--control-plane-endpoint`, `etcdctl snapshot save`/`restore` |
| [Lab 06](lab-06-helm/) | Helm: Install, Upgrade, Rollback | `helm repo add`, `--set`, `values.yaml`, `helm template` |
| [Lab 07](lab-07-kustomize/) | Kustomize: Base + Overlays | `namePrefix`, `images`, `patches`, `kubectl apply -k` |
| [Lab 08](lab-08-rbac/) | RBAC: Roles, RoleBindings, ServiceAccounts | `kubectl auth can-i`, ClusterRole, namespace scope |

---

## Domain 2 — Workloads and Scheduling (15%)

| Lab | Title | Key Skill |
|-----|-------|-----------|
| [Lab 09](lab-09-crds-operators/) | CRDs and Operators | `kubectl api-resources`, openAPIV3Schema, cert-manager |
| [Lab 10](lab-10-extension-interfaces/) | Extension Interfaces: CRI / CNI / CSI | `crictl`, `/etc/cni/net.d`, `kubectl get csidrivers` |
| [Lab 11](lab-11-deployments-rollout/) | Deployments and Rollouts | rolling update, bad image, `rollout undo`, pause/resume |
| [Lab 12](lab-12-configmaps/) | ConfigMaps: 3 Creation Methods | `envFrom`, volume mount, live update semantics |
| [Lab 13](lab-13-secrets/) | Secrets: Types and Injection | generic/tls/docker-registry, tmpfs mount, `defaultMode 0400` |
| [Lab 14](lab-14-hpa/) | HPA v2: Horizontal Pod Autoscaler | `metrics-server`, CPU target, load test, watch scale |
| [Lab 15](lab-15-self-healing/) | Self-Healing: Probes, RS, DS, StatefulSet | liveness/readiness, DaemonSet, StatefulSet ordering |
| [Lab 16](lab-16-scheduling/) | Scheduling: Affinity, Taints, Resources | `nodeSelector`, `nodeAffinity`, taints/tolerations, limits |

---

## Domain 3 — Services and Networking (20%)

| Lab | Title | Key Skill |
|-----|-------|-----------|
| [Lab 17](lab-17-pod-connectivity/) | Pod Connectivity and DNS Discovery | flat pod network, `curl`, `nslookup`, `netshoot` |
| [Lab 18](lab-18-service-types/) | Service Types: ClusterIP, NodePort, LoadBalancer | EndpointSlices, selector debug, MetalLB |
| [Lab 19](lab-19-ingress/) | Ingress: Host Routing, TLS, Path Rules | ingress-nginx, `ingressClassName`, TLS termination |
| [Lab 20](lab-20-gateway-api/) | Gateway API: GatewayClass, HTTPRoute | GA in v1.28, `gateway.networking.k8s.io/v1` |
| [Lab 21](lab-21-network-policies/) | NetworkPolicy: Default-Deny, Selectors | pod/namespace selector, egress lockdown |
| [Lab 22](lab-22-coredns/) | CoreDNS: Corefile, Headless, Stub Zones | `nslookup`, headless service, Corefile ConfigMap |

---

## Domain 4 — Storage (10%)

| Lab | Title | Key Skill |
|-----|-------|-----------|
| [Lab 23](lab-23-pv-pvc/) | PersistentVolume and PVC: Static Provisioning | access modes, reclaim policy, binding |
| [Lab 24](lab-24-storageclass/) | StorageClass: Dynamic Provisioning | CSI provisioner, default class, `volumeClaimTemplates` |
| [Lab 25](lab-25-volume-types/) | Volume Types: emptyDir, hostPath, projected | downwardAPI, service-account token projection |

---

## Domain 5 — Troubleshooting (30%)

| Lab | Title | Key Skill |
|-----|-------|-----------|
| [Lab 26](lab-26-troubleshoot-components/) | Troubleshoot Cluster Components | static pods, `/etc/kubernetes/manifests/`, `crictl logs` |
| [Lab 27](lab-27-troubleshoot-nodes/) | Troubleshoot Nodes: NotReady, kubelet | `journalctl -u kubelet`, `systemctl`, drain/uncordon |
| [Lab 28](lab-28-logs-streams/) | Application Logs: kubectl logs, Previous, Raw | `--previous`, multi-container, `/var/log/pods/` |
| [Lab 29](lab-29-monitoring/) | Monitor Cluster Usage: kubectl top, Events | `metrics-server`, `kubectl top`, `kubectl get events` |
| [Lab 30](lab-30-troubleshoot-net/) | Troubleshoot Networking: DNS, Services, CNI | selector debug, CoreDNS, endpoints, NetworkPolicy |
| [Lab 31](lab-31-troubleshoot-rbac-sched/) | Troubleshoot RBAC (403) and Scheduling (Pending) | `kubectl auth can-i`, taint/toleration, node status |

---

## Practicum Assessments

Hands-on summative assessments, one per training day:

| Assessment | Coverage | Time |
|------------|----------|------|
| [Practicum 1](assessments/practicum-1/question.md) | Domain 1 — Cluster Architecture & Installation | 45 min |
| [Practicum 2](assessments/practicum-2/question.md) | Domain 2 — Workloads & Scheduling | 45 min |
| [Practicum 3](assessments/practicum-3/question.md) | Domains 3 & 4 — Networking & Storage | 45 min |
| [Practicum 4](assessments/practicum-4/question.md) | Domain 5 + Final Mock (all domains) | 2 hr |

---

## Software requirements

See [tools.md](tools.md) for the complete free-tool list with install commands.
