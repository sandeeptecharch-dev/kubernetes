# TechUdaan: Kubernetes Zero Se 🚀

> **AI will write the code. You will run the system.**

Hands-on Kubernetes course for engineering students. No prior Kubernetes experience is needed. Everything runs on **your own laptop** with **free, open-source tools**.

AI agents can now draft Dockerfiles, Kubernetes YAML and Helm charts in seconds. Production still needs engineers who understand what's running underneath: people who can judge what is safe to change, find the real cause of an outage and own the outcome. **You can only supervise an AI agent on a system you understand.** This course builds that understanding, starting from the architecture.

---

## 📚 Course Modules

| # | Module | What you'll learn | Status |
|---|--------|-------------------|--------|
| — | **[Create a cluster: kind, AWS EKS, Azure AKS, Google GKE](cluster-setup/)** | From the basics: local and cloud clusters, costs, cleanup | ✅ Available |
| 0 | **[Setup: install Docker, kubectl, kind](module-00-setup/)** | Get a 3-node cluster running on your laptop | ✅ Available |
| 1 | **[Kubernetes Architecture](module-01-architecture/)** | Control plane, worker nodes, how a deployment actually happens | ✅ Available |
| 2 | Pods | What a Pod really is; write your first Pod YAML by hand | 🔜 Coming soon |
| 3 | **[Kubernetes Components](module-03-components/)** | Deep dive into all 9 components, with hands-on proof for each | ✅ Available |
| 4 | **[kind & kubectl, hands-on](module-04-kind-kubectl/)** | Build clusters, essential kubectl, deploy apps, run your own image | ✅ Available |
| 5 | **[Clusters, Nodes & Namespaces](module-05-clusters-nodes-namespaces/)** | Node labels & maintenance, namespaces, quotas and limits | ✅ Available |
| 6 | Deployments & ReplicaSets | Scaling, rolling updates, rollbacks, self-healing | 🔜 Coming soon |
| 7 | Services & Networking | ClusterIP, NodePort, DNS, labels and selectors | 🔜 Coming soon |
| 8 | ConfigMaps, Secrets & Storage | App configuration, credentials, persistent volumes | 🔜 Coming soon |
| 9 | Ingress & Helm | Routing traffic, packaging apps | 🔜 Coming soon |
| 10 | Observability & Troubleshooting | Probes, logs, metrics, a debugging method | 🔜 Coming soon |
| 11 | Capstone | Deploy a 3-tier app that survives failures | 🔜 Coming soon |

Every module follows the same loop:

```
Understand → Watch → Do → Break → Fix
```

Each module has **concepts**, a **hands-on lab**, a **break-it-and-fix-it exercise** and a **self-check quiz**.

---

## 🧠 Module 1 at a Glance: Kubernetes Architecture

```
                    You (kubectl)
                          │
┌─────────────────────────▼──────────────────────────┐
│  CONTROL PLANE (the brain)                         │
│                                                    │
│   etcd  ◄──►  kube-apiserver  ◄──  kube-scheduler  │
│  (database)   (front door)    ◄──  controller-mgr  │
└─────────────────────────▲──────────────────────────┘
                          │  watch and report
          ┌───────────────┴───────────────┐
┌─────────┴──────────┐         ┌──────────┴─────────┐
│  WORKER NODE 1     │         │  WORKER NODE 2     │
│  kubelet           │         │  kubelet           │
│  containerd        │         │  containerd        │
│  kube-proxy        │         │  kube-proxy        │
│  [Pod] [Pod] [Pod] │         │  [Pod] [Pod] [Pod] │
└────────────────────┘         └────────────────────┘
```

**Key rule:** components never talk to each other directly. Everything goes through the API server.

| Component | Railway analogy | Job |
|-----------|-----------------|-----|
| kube-apiserver | Reservation counter | The only door into the cluster |
| etcd | Master reservation chart | Stores the entire cluster state |
| kube-scheduler | Platform allocation officer | Picks a node for each new Pod |
| kube-controller-manager | Station inspectors | Keeps actual state equal to desired state |
| kubelet | Station master | Runs Pods on its node and reports status |
| containerd | Engine driver | Pulls images and starts containers |
| kube-proxy | Platform signboards | Routes Service traffic to the right Pods |

---

## 🛠️ Prerequisites

📋 **Cheat sheet:** [kind, cluster and context commands](cheatsheets/kind-cluster-context.md)

👉 **Step-by-step install guide for Windows (WSL2), macOS and Linux: [module-00-setup](module-00-setup/README.md).** Then run `bash module-00-setup/check-setup.sh` to confirm everything works.

| Tool | Purpose | Install |
|------|---------|---------|
| Docker | Runs the kind cluster nodes as containers | [Docker Desktop](https://docs.docker.com/get-docker/) or Docker Engine in WSL2 |
| kind | Kubernetes in Docker: a real cluster on your laptop | [kind quick start](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) |
| kubectl | The Kubernetes command-line tool | [Install kubectl](https://kubernetes.io/docs/tasks/tools/) |
| Git | Clone this repo | [git-scm.com](https://git-scm.com/downloads) |

**Laptop:** 8 GB RAM is enough. On Windows, use **WSL2 with Ubuntu**.
**No capable laptop?** Use a free browser lab such as [Killercoda](https://killercoda.com) (free tier has limits).

---

## ⚡ Quick Start

**1. Clone the repo**

```bash
git clone https://github.com/<your-org>/techudaan-kubernetes.git
cd techudaan-kubernetes
```

**2. Create a 3-node cluster** using the config in [`module-01-architecture/kind-3node.yaml`](module-01-architecture/kind-3node.yaml):

```bash
kind create cluster --name techudaan --config module-01-architecture/kind-3node.yaml
kubectl get nodes
```

Expected output:

```
NAME                      STATUS   ROLES           AGE   VERSION
techudaan-control-plane   Ready    control-plane   1m    v1.x.x
techudaan-worker          Ready    <none>          1m    v1.x.x
techudaan-worker2         Ready    <none>          1m    v1.x.x
```

**3. Find the architecture components**

```bash
kubectl get pods -n kube-system -o wide
```

**4. Deploy your first app and watch the journey**

```bash
kubectl create deployment web --image=nginx --replicas=3
kubectl get pods -o wide
kubectl get events --sort-by=.metadata.creationTimestamp
```

**5. Clean up when done**

```bash
kind delete cluster --name techudaan
```

> 💡 On an 8 GB laptop, close heavy browser tabs. Still slow? Remove one `worker` line in `kind-3node.yaml` for a 2-node cluster.

**Start learning:** [notes](module-01-architecture/notes.md) → [lab](module-01-architecture/lab.md) → [break it and fix it](module-01-architecture/break-fix.md) → [quiz](module-01-architecture/quiz.md)

---

## 💥 Break It and Fix It (Module 1)

> ⚠️ Run these **only on your kind lab cluster**, never on a real cluster.

| Exercise | Break | What you'll observe |
|----------|-------|---------------------|
| Scheduler on leave | Move `kube-scheduler.yaml` out of `/etc/kubernetes/manifests` | New Pods stay `Pending`; old Pods keep running |
| Station master down | `systemctl stop kubelet` on a worker | Node turns `NotReady`; Pods move to another node |
| Front door closed | Move `kube-apiserver.yaml` out | `kubectl` fails, but your apps keep running |

Full steps and fixes: [`module-01-architecture/break-fix.md`](module-01-architecture/break-fix.md)

---

## 🤖 Rules for Using AI While Learning

1. **Try it yourself first:** give it 20 minutes before asking AI.
2. **Ask AI to explain, not to solve:** "Why does this error happen?" rather than "Fix this."
3. **Understand every line** of AI-generated YAML before you apply it.
4. **Debugging tests are AI-off.** In production, you are the one who decides.

---

## 📁 Repository Structure

```
techudaan-kubernetes/
├── README.md
├── cluster-setup/
│   ├── README.md                 # Start here: local vs cloud, costs, golden rules
│   ├── 01-kind.md                # Local cluster (free)
│   ├── 02-aws-eks.md             # Amazon EKS with eksctl
│   ├── 03-azure-aks.md           # Azure AKS with az
│   └── 04-gcp-gke.md             # Google GKE with gcloud
├── cheatsheets/
│   └── kind-cluster-context.md   # kind, kubeconfig/context, cluster & node commands
├── module-00-setup/
│   ├── README.md           # Install Docker, kubectl, kind, Git (Windows/macOS/Linux)
│   └── check-setup.sh      # Checks your tools are ready
├── module-01-architecture/
│   ├── notes.md            # Concepts, analogies, deployment journey
│   ├── kind-3node.yaml     # Lab cluster config
│   ├── lab.md              # Hands-on lab steps
│   ├── break-fix.md        # Break it and fix it exercises
│   └── quiz.md             # Self-check quiz + interview questions
├── module-02-pods/
│   └── README.md           # Coming soon
├── module-03-components/
│   ├── notes.md            # Overview of all 9 components + study order
│   ├── components/         # One full guide per component (explanation + practical)
│   │   ├── 01-kube-apiserver.md
│   │   ├── 02-etcd.md
│   │   ├── 03-kube-scheduler.md
│   │   ├── 04-kube-controller-manager.md
│   │   ├── 05-kubelet.md
│   │   ├── 06-container-runtime.md
│   │   ├── 07-kube-proxy.md
│   │   ├── 08-coredns.md
│   │   └── 09-cni-plugin.md
│   ├── lab.md              # One proof per component (etcd, static Pods, crictl...)
│   ├── break-fix.md        # 5 real problems, each owned by a different component
│   └── quiz.md             # 10 questions + interview questions
├── module-04-kind-kubectl/
│   ├── README.md           # 9 hands-on labs: kind, kubectl, deploy, your own image
│   ├── kind-configs/       # 1-node, 3-node, port-mapping and HA cluster configs
│   ├── manifests/          # hello Deployment + NodePort Service
│   ├── my-app/             # Dockerfile, index.html, my-app.yaml (your own image)
│   └── scripts/
│       └── verify-cluster.sh   # checks your cluster is healthy
├── module-05-clusters-nodes-namespaces/
│   ├── README.md           # 8 labs: nodes, maintenance, namespaces, quotas
│   ├── kind-configs/       # kind-labeled.yaml (workers with labels)
│   ├── manifests/          # namespaces, web-app, resource-quota, limit-range
│   └── scripts/
│       └── node-report.sh      # one-screen report of every node
└── ...
```

---

## 🎓 Certification Path

| TechUdaan level | Prepares you for |
|-----------------|------------------|
| Udaan 1: Cluster Ready | KCNA (Kubernetes and Cloud Native Associate) |
| Udaan 2: Production Ready | CKAD (Certified Kubernetes Application Developer) |
| Udaan 3: Platform Ready | CKA (Certified Kubernetes Administrator) |

Certification exams are run and priced by the Linux Foundation. Check [training.linuxfoundation.org](https://training.linuxfoundation.org) for current details.

---

## 🤝 Contributing

Found a mistake, a broken command or a better analogy? Contributions are welcome.

1. Fork the repo
2. Create a branch: `git checkout -b fix/module-01-typo`
3. Commit your change: `git commit -m "Fix typo in Module 1 lab"`
4. Push and open a Pull Request

Please test every command on a fresh kind cluster before submitting.

---

## 💬 Community

- **Discord:** _link coming soon_
- **YouTube:** _link coming soon_
- **LinkedIn:** _link coming soon_

⭐ **Star this repo** if it helped you, and share it with a friend who's starting their Kubernetes journey.

---

## 📄 License

Course content © TechUdaan. Code samples are free to use for learning.
_(Choose a license before publishing, for example MIT for code and CC BY-NC-SA 4.0 for course content.)_
