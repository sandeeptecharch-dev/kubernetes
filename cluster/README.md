# Creating a Kubernetes Cluster: Start Here 🚀

> One course, four ways to get a cluster: on your laptop with **kind**, or in the cloud with **AWS EKS**, **Azure AKS** or **Google GKE**. Same Kubernetes, same `kubectl`, different places.

🏠 [Back to course home](../README.md)

---

## 1. First, the Very Basics

### What is a "cluster"?

A **Kubernetes cluster** is a group of machines working together as one system:

- **Control plane** (the brain): decides what runs where. API server, etcd, scheduler, controller manager.
- **Worker nodes** (the muscle): actually run your apps in Pods.

You talk to any cluster the same way: with **`kubectl`**.

```
                 kubectl  (same commands everywhere)
                    │
   ┌────────────────┼────────────────┬────────────────┐
   ▼                ▼                ▼                ▼
  kind            AWS EKS         Azure AKS       Google GKE
 (laptop)         (cloud)          (cloud)          (cloud)
```

### Two ways to run Kubernetes

| | **Local cluster** (kind) | **Managed cloud cluster** (EKS / AKS / GKE) |
|---|---|---|
| Where it runs | Docker containers on your laptop | Real virtual machines in a cloud data centre |
| Who runs the control plane | You (it's a container on your laptop) | **The cloud provider.** You never see those machines |
| Cost | Free | Pay per hour (control plane and/or nodes, disks, load balancers) |
| Internet access to your app | Only through port-forwarding / port mapping | Real public IPs and cloud load balancers |
| Best for | Learning, practising, breaking things | Learning what companies use in production |

> 💡 **"Managed" means:** the cloud provider runs, patches, backs up and scales the control plane for you. That's why on EKS/AKS/GKE you **won't** see `kube-apiserver` or `etcd` Pods in `kube-system`. (Compare this with what you saw on kind in [Module 3](../module-03-components/notes.md).)

---

## 2. Which Guide Should I Follow?

| # | Guide | Time to create | Cost | Start here if... |
|---|---|---|---|---|
| 01 | [kind (local)](01-kind.md) | 1–3 min | **Free** | You're learning. **Everyone starts here.** |
| 02 | [AWS EKS](02-aws-eks.md) | 15–20 min | Paid (control plane + nodes) | You're targeting AWS jobs |
| 03 | [Azure AKS](03-azure-aks.md) | 5–10 min | Free control plane (Free tier) + nodes | You have Azure for Students credits |
| 04 | [Google GKE](04-gcp-gke.md) | 5–10 min | One zonal/Autopilot cluster's fee covered by free tier credit + nodes | You have GCP free trial credits |

**Recommended order for this course:**

1. Do **all modules on kind**. It's free and you can break it without worry.
2. When comfortable, create **one** cloud cluster, run the same labs, and compare.
3. **Delete the cloud cluster the same day.**

---

## 3. Golden Rules for Cloud Clusters 💸

Cloud clusters cost real money **every hour they exist**, even if you're not using them. Students get surprise bills every year. Follow these rules every time:

| # | Rule | Why |
|---|---|---|
| 1 | **Set a budget alert before creating anything** | You get an email before costs grow |
| 2 | **Use the smallest node size and count** that works (2 small nodes) | Nodes are the biggest cost |
| 3 | **Create, learn, delete, all on the same day** | A forgotten cluster costs money 24/7 |
| 4 | **Delete Services of type `LoadBalancer` before deleting the cluster** | Load balancers can be left behind and keep billing |
| 5 | **After deleting, check that nothing is left** (each guide shows how) | Disks, IPs and load balancers can survive the cluster |
| 6 | **Never commit cloud keys or passwords to Git** | Leaked keys are found by bots within minutes |
| 7 | **Use a region close to you** (India: Mumbai / Central India) | Lower latency |

> ⚠️ Prices, free credits and free tiers change. Each guide links the official pricing page; check it before you start.

---

## 4. The Same Test in Every Guide

Every guide ends with the same steps, so you can compare clusters fairly:

```bash
kubectl get nodes -o wide                 # how many nodes, which OS/runtime?
kubectl get pods -n kube-system           # which system components can you see?
kubectl create deployment hello --image=nginx --replicas=2
kubectl expose deployment hello --port=80 --type=LoadBalancer   # cloud only
kubectl get svc hello -w                  # wait for EXTERNAL-IP
```

✍️ **Compare and write down:** which `kube-system` Pods appear on kind but not on the cloud clusters? Why?

---

## 5. What Gets Installed Where

| Tool | kind | EKS | AKS | GKE |
|---|---|---|---|---|
| Docker | ✅ | — | — | — |
| kubectl | ✅ | ✅ | ✅ | ✅ |
| kind | ✅ | — | — | — |
| AWS CLI v2 | — | ✅ | — | — |
| eksctl | — | ✅ | — | — |
| Azure CLI (`az`) | — | — | ✅ | — |
| Google Cloud CLI (`gcloud`) + `gke-gcloud-auth-plugin` | — | — | — | ✅ |

> 💡 On Windows, run everything inside **WSL2 Ubuntu** (see [Module 0](../module-00-setup/README.md)). Every command in these guides then works as written.

---

➡️ Start with [01. kind (local cluster)](01-kind.md)
