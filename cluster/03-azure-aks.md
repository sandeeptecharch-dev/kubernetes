# 03. Create a Cluster on Microsoft Azure (AKS) ☁️

> Create a managed Kubernetes cluster on Azure with the `az` command line, connect `kubectl`, expose an app on a public IP, and delete everything with one command.

⬅️ Previous: [02. AWS EKS](02-aws-eks.md) | ➡️ Next: [04. Google GKE](04-gcp-gke.md)

---

## 1. What Is AKS?

**AKS** (Azure Kubernetes Service) is Microsoft Azure's managed Kubernetes.

```
┌──────────── Managed by Azure (hidden from you) ─────────────┐
│  Control plane: kube-apiserver, etcd, scheduler, ...        │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌──────── In YOUR subscription ───────────────────────────────┐
│  Resource group "techudaan-rg"      ← the AKS cluster object│
│  Resource group "MC_techudaan-rg_…" ← nodes, disks, network,│
│                                       load balancer         │
│     (created and managed by AKS automatically)              │
└─────────────────────────────────────────────────────────────┘
```

### Words you'll meet

| Term | Simple meaning |
|---|---|
| **Subscription** | Your Azure billing account. All costs go here |
| **Resource group** | A folder that holds related Azure resources. Delete the folder → delete everything in it |
| **Region / location** | Where the data centre is. India: `centralindia` (Pune), `southindia` (Chennai) |
| **Node pool** | A group of worker VMs of the same size |
| **VM size** | The CPU/RAM of each node, e.g. `Standard_B2s` = 2 vCPU, 4 GB RAM |
| **Node resource group (`MC_...`)** | A second resource group AKS creates to hold the node VMs, disks and networking |
| **`az`** | The Azure command-line tool |

---

## 2. What It Costs 💸

| Item | Charged? |
|---|---|
| Control plane, **Free tier** | **Free**. You pay only for the underlying resources. Fine for learning; not meant for more than about 10 nodes or high-availability needs |
| Control plane, Standard tier (with SLA) | Paid per cluster per hour. For production |
| Worker nodes (VMs), disks, public IPs, load balancer | Yes, while they exist |

**Free credits:**
- **Azure free account:** $200 credit to use within 30 days ([details](https://azure.microsoft.com/free/))
- **Azure for Students:** $100 credit for 12 months, **no credit card required**; sign up with your college email ([details](https://azure.microsoft.com/free/students/))

📊 [AKS pricing](https://azure.microsoft.com/pricing/details/kubernetes-service/) · [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/)

**Rule:** create → learn → delete **the same day** (or at least **stop** the cluster; see section 10).

---

## 3. Before You Start

- [ ] An **Azure account** (free account, or Azure for Students)
- [ ] **kubectl** installed ([Module 0](../module-00-setup/README.md))
- [ ] Linux, macOS, or **WSL2 Ubuntu** on Windows

### Step 0: Set a budget alert (do this first!)

1. Go to the [Azure Portal](https://portal.azure.com).
2. Search **Cost Management** → **Budgets** → **+ Add**.
3. Scope: your subscription. Amount: e.g. **₹800 / $10**. Add your email for alerts at 50%, 80% and 100%.
4. **Create**.

---

## 4. Install the Azure CLI

**Linux / WSL (Ubuntu or Debian):**

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

**macOS:**

```bash
brew install azure-cli
```

Check:

```bash
az version
```

> 💡 Optional: `az aks install-cli` installs `kubectl` (and `kubelogin`) for you. Skip it if you already have kubectl.

---

## 5. Log In and Prepare Your Subscription

### 5a. Log in

```bash
az login
```

A browser opens; sign in. **On WSL**, if no browser opens, use:

```bash
az login --use-device-code
```

Then open the link shown, enter the code, and sign in.

### 5b. Check which subscription you're using

```bash
az account show --output table
```

Have several? Pick one:

```bash
az account list --output table
az account set --subscription "<subscription name or id>"
```

### 5c. Register the Kubernetes service (first time only)

New subscriptions must "switch on" AKS before using it:

```bash
az provider register --namespace Microsoft.ContainerService
az provider show --namespace Microsoft.ContainerService --query registrationState --output tsv
```

Repeat the second command until it says **`Registered`** (1–2 minutes).

### 5d. Create a resource group

```bash
az group create --name techudaan-rg --location centralindia
```

✅ `"provisioningState": "Succeeded"`

> 💡 **Azure for Students** subscriptions may only allow certain regions. If you get a `RequestDisallowedByPolicy` error, try another region (e.g. `southindia`, `eastus`) and use it everywhere below.

---

## 6. Create the Cluster

```bash
az aks create \
  --resource-group techudaan-rg \
  --name techudaan-aks \
  --tier free \
  --node-count 2 \
  --node-vm-size Standard_B2s \
  --generate-ssh-keys
```

| Flag | Meaning |
|---|---|
| `--resource-group techudaan-rg` | Put the cluster in this resource group |
| `--name techudaan-aks` | Cluster name |
| `--tier free` | Free control plane (no SLA). Perfect for learning |
| `--node-count 2` | 2 worker nodes |
| `--node-vm-size Standard_B2s` | Each node: 2 vCPU, 4 GB RAM (small, low-cost) |
| `--generate-ssh-keys` | Creates SSH keys for the nodes if you don't have them |

⏱️ Takes **5–10 minutes**. When done, you get a large JSON output with `"provisioningState": "Succeeded"`.

> If `Standard_B2s` isn't available in your region or subscription, try `Standard_B2s_v2` or `Standard_D2s_v3`.

---

## 7. Connect kubectl

```bash
az aks get-credentials --resource-group techudaan-rg --name techudaan-aks
kubectl config current-context
```

✅ The context is named **`techudaan-aks`**.

Rename it to match the course style (optional):

```bash
kubectl config rename-context techudaan-aks aks-techudaan
```

---

## 8. Explore Your AKS Cluster

```bash
kubectl get nodes -o wide
```

✅ 2 nodes, named like `aks-nodepool1-12345678-vmss000000`, OS **Ubuntu** or **Azure Linux**, runtime **containerd**.

> 💡 `vmss` in the name = **Virtual Machine Scale Set**, the Azure feature AKS uses to create and scale node VMs.

```bash
kubectl get pods -n kube-system
```

✅ You'll see Pods such as `coredns`, `kube-proxy`, `konnectivity-agent`, `metrics-server` and Azure networking/storage Pods. The exact list depends on your cluster's network settings.

✍️ **Compare with kind:**

| | kind | AKS |
|---|---|---|
| `kube-apiserver`, `etcd`, `kube-scheduler` Pods | ✅ Visible | ❌ **Hidden**: Azure runs them |
| `konnectivity-agent` | ❌ | ✅ A secure tunnel from the nodes to the hidden control plane |
| `metrics-server` | ❌ (not installed by kind) | ✅ Installed, so `kubectl top nodes` works immediately |

Try it:

```bash
kubectl top nodes
```

### See what Azure created for you

```bash
NODE_RG=$(az aks show --resource-group techudaan-rg --name techudaan-aks --query nodeResourceGroup --output tsv)
echo $NODE_RG
az resource list --resource-group $NODE_RG --output table
```

✅ The `MC_techudaan-rg_techudaan-aks_centralindia` group holds a **VM scale set** (your nodes), **disks**, a **virtual network**, a **load balancer** and a **public IP**.

> ⚠️ Never edit or delete resources in the `MC_` group by hand. AKS manages them.

---

## 9. Expose the App to the Internet

```bash
kubectl create deployment hello --image=nginx --replicas=2
kubectl expose deployment hello --port=80 --type=LoadBalancer
kubectl get svc hello -w
```

After about 1 minute, `EXTERNAL-IP` changes from `<pending>` to a public IP. Press `Ctrl+C`.

```bash
IP=$(kubectl get svc hello -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "http://$IP"
curl -s http://$IP | head -4
```

Open it in your browser: **"Welcome to nginx!"** 🎉

**What happened:** Kubernetes asked Azure to add a **public IP and a load-balancing rule** to the cluster's Azure Load Balancer. Check: `az network public-ip list --resource-group $NODE_RG --output table`.

---

## 10. Pause or Delete 🧹

### Option A: Pause the cluster (stop paying for nodes)

```bash
az aks stop --resource-group techudaan-rg --name techudaan-aks
```

The node VMs are switched off and your cluster's configuration is kept. Start it again later with:

```bash
az aks start --resource-group techudaan-rg --name techudaan-aks
```

> 💡 Some resources (like disks and public IPs) can still cost a little while stopped. For a full stop to charges, delete the cluster.

### Option B: Delete everything (recommended at the end of each session)

First delete the LoadBalancer Service:

```bash
kubectl delete service hello
kubectl delete deployment hello
```

Then delete the **resource group**. This removes the cluster **and** the `MC_` node resource group:

```bash
az group delete --name techudaan-rg --yes
```

⏱️ About 5–10 minutes. (Add `--no-wait` to return immediately.)

### Confirm nothing is left

```bash
az group list --output table
az aks list --output table
```

✅ No `techudaan-rg` and no `MC_techudaan-rg_...` groups remain (you may see a `NetworkWatcherRG` group, which Azure creates automatically and which is normally free).

Clean up kubeconfig:

```bash
kubectl config delete-context aks-techudaan 2>/dev/null || kubectl config delete-context techudaan-aks
```

---

## 11. Troubleshooting

| Error | Fix |
|---|---|
| `MissingSubscriptionRegistration` | Run step 5c (`az provider register ...`) and wait for `Registered` |
| `exceeding approved ... Cores quota` | Your subscription has a low vCPU limit. Use `--node-count 1`, a smaller VM size, or request a quota increase |
| `The VM size of Standard_B2s is not allowed / not available` | Try `Standard_B2s_v2` or `Standard_D2s_v3`, or another region |
| `RequestDisallowedByPolicy` | Your subscription (often Azure for Students) restricts regions. Try another region |
| `az login` doesn't open a browser (WSL) | Use `az login --use-device-code` |
| `kubectl` says `Unauthorized` | Re-run `az aks get-credentials ... --overwrite-existing` |
| `EXTERNAL-IP` stuck on `<pending>` | `kubectl describe svc hello` → Events; check public IP quota |

---

## ✅ Recap

- AKS = Azure runs the **control plane** (Free tier: no control-plane fee); your **nodes are VMs** in a VM scale set.
- Everything lives in **resource groups**; AKS adds an `MC_...` group for the nodes and networking.
- `az aks stop` pauses node costs; **`az group delete`** removes everything in one go.

➡️ Next: [04. Google GKE](04-gcp-gke.md)
