# 04. Create a Cluster on Google Cloud (GKE) ☁️

> Create a managed Kubernetes cluster on Google Cloud with `gcloud`, connect `kubectl`, look inside a real node, expose an app publicly, and clean up completely.

⬅️ Previous: [03. Azure AKS](03-azure-aks.md) | 🏠 [Cluster setup home](README.md)

---

## 1. What Is GKE?

**GKE** (Google Kubernetes Engine) is Google Cloud's managed Kubernetes. Kubernetes itself was born at Google, and GKE was the first managed Kubernetes service.

```
┌──────────── Managed by Google (hidden from you) ─────────────┐
│  Control plane: kube-apiserver, etcd, scheduler, ...         │
└───────────────────────────┬──────────────────────────────────┘
                            │
┌──────── In YOUR Google Cloud project ────────────────────────┐
│  Standard mode:  node pool = Compute Engine VMs you can see  │
│  Autopilot mode: Google also manages the nodes for you       │
│  + disks, load balancers, IPs when you create them           │
└──────────────────────────────────────────────────────────────┘
```

### Two modes: Standard vs Autopilot

| | **Standard** | **Autopilot** |
|---|---|---|
| Who manages nodes | You (choose machine type and count) | Google |
| You pay for | Node VMs | The CPU/memory your Pods request |
| SSH into nodes, run privileged Pods | ✅ Yes | ❌ Restricted |
| Best for this course | ✅ **Yes**: you can see and debug everything | Good for "just run my app" |

This guide uses **Standard, zonal** (main path) and shows Autopilot as an option.

### Words you'll meet

| Term | Simple meaning |
|---|---|
| **Project** | A container for all your Google Cloud resources and billing. Delete the project → delete everything |
| **Billing account** | Where charges and credits go; linked to a project |
| **Region / zone** | Mumbai region = `asia-south1`; a zone inside it = `asia-south1-a` |
| **Zonal cluster** | Control plane in **one** zone (cheapest; covered by the free tier credit) |
| **Regional cluster** | Control plane copies in **3** zones (production; not covered by free tier) |
| **Node pool** | A group of nodes with the same machine type |
| **`gcloud`** | The Google Cloud command-line tool |

---

## 2. What It Costs 💸

| Item | Charged? |
|---|---|
| Cluster management fee | $0.10 per cluster per hour |
| GKE free tier | $74.40 monthly credit per billing account, enough for **one zonal or Autopilot cluster's** management fee. It doesn't cover regional clusters or compute |
| Nodes (Standard) / Pod resources (Autopilot), disks, load balancers | Yes, while they exist |

**Free credits:** new Google Cloud customers get **$300** in free credits to try GKE ([details](https://cloud.google.com/free)).

📊 [GKE pricing](https://cloud.google.com/kubernetes-engine/pricing) · [Google Cloud pricing calculator](https://cloud.google.com/products/calculator)

**Rule:** create → learn → delete **the same day**.

---

## 3. Before You Start

- [ ] A **Google account** and a [Google Cloud account](https://cloud.google.com/free) with billing set up (free trial is fine)
- [ ] **kubectl** installed ([Module 0](../module-00-setup/README.md))
- [ ] Linux, macOS, or **WSL2 Ubuntu** on Windows

### Step 0: Set a budget alert (do this first!)

1. Open the [Google Cloud Console](https://console.cloud.google.com).
2. Menu → **Billing** → **Budgets & alerts** → **Create budget**.
3. Set an amount (e.g. **$10**), keep the default alert thresholds (50%, 90%, 100%) → **Finish**.

---

## 4. Install the Google Cloud CLI

**Linux / WSL / macOS** (official interactive installer):

```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

Accept the defaults when asked. Then check:

```bash
gcloud version
```

### Install the GKE login plugin (required for kubectl)

`kubectl` needs a small plugin to log in to GKE clusters:

```bash
gcloud components install gke-gcloud-auth-plugin
gke-gcloud-auth-plugin --version
```

> 💡 If you installed `gcloud` with `apt` instead, run `sudo apt-get install google-cloud-cli-gke-gcloud-auth-plugin`.

---

## 5. Log In and Prepare a Project

### 5a. Log in and initialise

```bash
gcloud init
```

It opens a browser to sign in (on WSL, follow the link it prints), then asks you to **pick or create a project** and a default region/zone. Choose zone **`asia-south1-a`** (Mumbai) if asked.

### 5b. Create a dedicated project (recommended)

A separate project makes cleanup easy: delete the project, and everything goes.

```bash
PROJECT_ID=techudaan-k8s-$RANDOM
gcloud projects create $PROJECT_ID --name="TechUdaan K8s"
gcloud config set project $PROJECT_ID
echo "Your project: $PROJECT_ID"
```

> ✍️ Write down your `PROJECT_ID`. You'll need it later.

### 5c. Link billing to the project

```bash
gcloud billing accounts list
gcloud billing projects link $PROJECT_ID --billing-account=<ACCOUNT_ID_FROM_ABOVE>
```

(Or in the Console: **Billing** → **My projects** → your project → **Change billing**.)

### 5d. Turn on the Kubernetes Engine API

```bash
gcloud services enable container.googleapis.com
```

⏱️ About 1 minute. This also enables Compute Engine for your nodes.

---

## 6. Create the Cluster

### Main path: Standard, zonal cluster (best for this course)

```bash
gcloud container clusters create techudaan \
  --location=asia-south1-a \
  --num-nodes=2 \
  --machine-type=e2-medium \
  --disk-type=pd-standard \
  --disk-size=30
```

| Flag | Meaning |
|---|---|
| `techudaan` | Cluster name |
| `--location=asia-south1-a` | A **zone**, so this is a **zonal** cluster (covered by the free tier credit) |
| `--num-nodes=2` | 2 worker nodes (per zone) |
| `--machine-type=e2-medium` | Each node: 2 shared vCPUs, 4 GB RAM |
| `--disk-type=pd-standard` | Standard disks (cheaper; avoids SSD quota limits on new accounts) |
| `--disk-size=30` | 30 GB disk per node |

⏱️ Takes **5–10 minutes**. When done:

```
NAME       LOCATION       MASTER_VERSION  ...  NUM_NODES  STATUS
techudaan  asia-south1-a  1.x.x-gke.x     ...  2          RUNNING
```

### Option: Autopilot cluster

```bash
gcloud container clusters create-auto techudaan-auto --location=asia-south1
```

Google manages the nodes; you pay for what your Pods request. Some labs in this course (SSH into nodes, static Pods, privileged tools) **won't work** on Autopilot.

---

## 7. Connect kubectl

`gcloud` usually configures kubectl when it creates the cluster. To do it yourself (e.g. on another laptop):

```bash
gcloud container clusters get-credentials techudaan --location=asia-south1-a
kubectl config current-context
```

✅ The context looks like `gke_<project-id>_asia-south1-a_techudaan`. Shorten it:

```bash
kubectl config rename-context $(kubectl config current-context) gke-techudaan
```

---

## 8. Explore Your GKE Cluster

```bash
kubectl get nodes -o wide
```

✅ 2 nodes named like `gke-techudaan-default-pool-xxxxxxxx-xxxx`, OS **Container-Optimized OS**, runtime **containerd**.

```bash
kubectl get pods -n kube-system
```

✅ You'll see Pods such as `kube-dns`, `konnectivity-agent`, `metrics-server`, `pdcsi-node` (disk driver), logging/metrics agents, and networking Pods (`kube-proxy`, or `anetd` if Dataplane V2 is on).

✍️ **Compare with kind:**

| | kind | GKE |
|---|---|---|
| `kube-apiserver`, `etcd`, `kube-scheduler` Pods | ✅ Visible | ❌ **Hidden**: Google runs them |
| Cluster DNS | CoreDNS | **kube-dns** (GKE's default DNS add-on) |
| Logging & monitoring agents | ❌ | ✅ Sending to Cloud Logging / Monitoring |

### Look inside a real cloud node (links to Module 3)

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
gcloud compute ssh $NODE --zone=asia-south1-a --command="sudo crictl ps | head -10; systemctl is-active kubelet"
```

✅ The same `crictl` and kubelet you studied on kind, now on a Google VM. (The first `gcloud compute ssh` creates an SSH key; press Enter at the prompts.)

### See what Google created

```bash
gcloud compute instances list
gcloud compute disks list
```

✅ Your 2 node VMs and their disks.

---

## 9. Expose the App to the Internet

```bash
kubectl create deployment hello --image=nginx --replicas=2
kubectl expose deployment hello --port=80 --type=LoadBalancer
kubectl get svc hello -w
```

After 1–2 minutes, `EXTERNAL-IP` shows a public IP. Press `Ctrl+C`.

```bash
IP=$(kubectl get svc hello -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "http://$IP"
curl -s http://$IP | head -4
```

Open it in your browser: **"Welcome to nginx!"** 🎉

**What happened:** GKE created a Google Cloud **network load balancer** (a forwarding rule) for your Service. See it with:

```bash
gcloud compute forwarding-rules list
```

---

## 10. Delete Everything 🧹

### Step 1: Delete the LoadBalancer Service first

```bash
kubectl delete service hello
kubectl delete deployment hello
```

Wait about 1 minute, then check the forwarding rule is gone:

```bash
gcloud compute forwarding-rules list
```

### Step 2: Delete the cluster

```bash
gcloud container clusters delete techudaan --location=asia-south1-a --quiet
```

⏱️ About 5 minutes.

### Step 3: Confirm nothing is left

```bash
gcloud container clusters list
gcloud compute instances list
gcloud compute disks list
gcloud compute forwarding-rules list
gcloud compute addresses list
```

✅ All lists empty.

Clean up kubeconfig:

```bash
kubectl config delete-context gke-techudaan
```

### Step 4 (optional, cleanest): Delete the whole project

If you created a dedicated project in step 5b:

```bash
gcloud projects delete $PROJECT_ID
```

This shuts down **everything** in the project. Google keeps it recoverable for a short period before it's permanently removed.

---

## 11. Troubleshooting

| Error | Fix |
|---|---|
| `Kubernetes Engine API has not been used in project ...` | Run `gcloud services enable container.googleapis.com` and wait a minute |
| `Billing account ... is not found` / billing not enabled | Link billing to the project (step 5c) |
| `gke-gcloud-auth-plugin ... not found` when using kubectl | Install it (section 4) and open a new terminal |
| `Quota 'SSD_TOTAL_GB' exceeded` | Use `--disk-type=pd-standard` and a smaller `--disk-size` |
| `Quota 'CPUS' exceeded` / `IN_USE_ADDRESSES` | Use `--num-nodes=1`, or request a quota increase in the Console |
| `ZONE_RESOURCE_POOL_EXHAUSTED` | That zone is out of capacity; try `asia-south1-b` or `asia-south1-c` |
| `EXTERNAL-IP` stuck on `<pending>` | `kubectl describe svc hello` → Events |
| Commands go to the wrong project | `gcloud config get-value project`, then `gcloud config set project <id>` |

---

## ✅ Recap

- GKE = Google runs the **control plane**; in **Standard** mode your nodes are Compute Engine VMs you can SSH into.
- A **zonal** or **Autopilot** cluster's management fee is covered by the GKE free tier credit; nodes, disks and load balancers are not.
- **Delete LoadBalancer Services first, then the cluster, then verify.** Deleting a dedicated project is the cleanest reset.

---

## 🏁 You've Now Created Kubernetes in 4 Places

| | kind | EKS | AKS | GKE |
|---|---|---|---|---|
| Create command | `kind create cluster` | `eksctl create cluster` | `az aks create` | `gcloud container clusters create` |
| Connect kubectl | automatic | `aws eks update-kubeconfig` | `az aks get-credentials` | `gcloud container clusters get-credentials` |
| Delete | `kind delete cluster` | `eksctl delete cluster` | `az group delete` | `gcloud container clusters delete` |
| Control-plane Pods visible | ✅ | ❌ | ❌ | ❌ |
| CNI by default | kindnet | Amazon VPC CNI | Azure networking (depends on cluster settings) | GKE networking (kube-proxy / Dataplane V2) |
| DNS add-on | CoreDNS | CoreDNS | CoreDNS | kube-dns |

**Same `kubectl`, same YAML, four different places.** That's the power of Kubernetes. 🚀

🏠 Back to [cluster setup home](README.md)
