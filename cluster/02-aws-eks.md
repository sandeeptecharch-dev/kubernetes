# 02. Create a Cluster on AWS (Amazon EKS) ☁️

> Create a real, managed Kubernetes cluster on Amazon Web Services using `eksctl`, connect `kubectl` to it, run an app with a public load balancer, and delete everything safely.

⬅️ Previous: [01. kind](01-kind.md) | ➡️ Next: [03. Azure AKS](03-azure-aks.md)

---

## 1. What Is Amazon EKS?

**Amazon EKS** (Elastic Kubernetes Service) is AWS's managed Kubernetes.

```
┌──────────── Managed by AWS (you never see these machines) ────────────┐
│   Control plane: kube-apiserver, etcd, scheduler, controller-manager  │
│   Highly available across multiple data centres (Availability Zones)  │
└───────────────────────────────┬───────────────────────────────────────┘
                                │
┌────────────── In YOUR AWS account (you pay for these) ────────────────┐
│   VPC (private network) + subnets                                     │
│   Worker nodes = EC2 virtual machines (managed node group)            │
│   Load balancers, disks (EBS), public IPs, when you create them       │
└───────────────────────────────────────────────────────────────────────┘
```

### Words you'll meet

| Term | Simple meaning |
|---|---|
| **Region** | A geographic location of AWS data centres. Mumbai = `ap-south-1` |
| **Availability Zone (AZ)** | One data centre inside a region (`ap-south-1a`, `1b`, `1c`) |
| **VPC** | Your private network in AWS |
| **EC2** | AWS virtual machines. Your worker nodes are EC2 instances |
| **Managed node group** | A group of EC2 worker nodes that EKS creates, updates and replaces for you |
| **IAM** | AWS's users, roles and permissions system |
| **CloudFormation** | AWS's infrastructure-as-code service. `eksctl` uses it behind the scenes |
| **eksctl** | The official command-line tool that creates an EKS cluster (and its VPC and nodes) with one command |

---

## 2. What It Costs 💸

| Item | Charged? |
|---|---|
| EKS control plane | **Yes, per cluster per hour.** $0.10/hour for a Kubernetes version in standard support; $0.60/hour for one in extended support |
| Worker nodes (EC2) | Yes, per instance per hour, based on instance type |
| Disks (EBS), load balancers, public IPs, NAT gateways | Yes, while they exist |

> ⚠️ **Always create clusters on a current Kubernetes version** (eksctl's default). Old versions in extended support cost 6× more for the control plane.

**Free credits:** new AWS customers get $100 in credits at sign-up and can earn up to $100 more. The Free plan lasts up to 6 months or until credits run out. EKS charges are taken from these credits. Check the current offer at [aws.amazon.com/free](https://aws.amazon.com/free).

📊 Estimate your exact cost: [EKS pricing](https://aws.amazon.com/eks/pricing/) · [AWS Pricing Calculator](https://calculator.aws/)

**Rule:** create → learn → delete **the same day**. A forgotten EKS cluster keeps charging every hour.

---

## 3. Before You Start

- [ ] An **AWS account** ([sign up](https://aws.amazon.com/free); a payment method is required, even on the Free plan)
- [ ] **kubectl** installed ([Module 0](../module-00-setup/README.md))
- [ ] Linux, macOS, or **WSL2 Ubuntu** on Windows

### Step 0: Set a budget alert (do this first!)

1. Sign in to the [AWS Console](https://console.aws.amazon.com/).
2. Search **Budgets** → **Create budget**.
3. Choose **Use a template** → **Monthly cost budget**.
4. Set an amount (e.g. **$10**) and your email → **Create budget**.

You'll get an email when spending approaches the limit.

---

## 4. Install the AWS Tools

### 4a. AWS CLI v2

**Linux / WSL (x86_64):**

```bash
sudo apt-get install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
```

(ARM64: replace `x86_64` with `aarch64`.)

**macOS:**

```bash
brew install awscli
```

Check: `aws --version` → `aws-cli/2.x.x ...`

### 4b. eksctl

**Linux / WSL:**

```bash
ARCH=amd64        # use arm64 on ARM machines
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo install -m 0755 /tmp/eksctl /usr/local/bin && rm /tmp/eksctl
```

**macOS:**

```bash
brew tap aws/tap
brew install aws/tap/eksctl
```

Check: `eksctl version`

---

## 5. Give the CLI Access to Your AWS Account

> ⚠️ **Never use your root account's keys.** Create a separate IAM user for the CLI.

### 5a. Create an IAM user with access keys

1. AWS Console → search **IAM** → **Users** → **Create user**.
2. Name it `techudaan-cli` → **Next**.
3. **Attach policies directly** → tick **AdministratorAccess** → **Next** → **Create user**.
   _(Fine for a personal learning account. In companies, you'd get narrower permissions.)_
4. Open the user → **Security credentials** → **Create access key** → choose **Command Line Interface (CLI)** → create.
5. Copy the **Access key ID** and **Secret access key**. The secret is shown **only once**.

### 5b. Configure the CLI

```bash
aws configure
```

| Prompt | Enter |
|---|---|
| AWS Access Key ID | your access key ID |
| AWS Secret Access Key | your secret key |
| Default region name | `ap-south-1` (Mumbai) |
| Default output format | `json` |

Verify who you are:

```bash
aws sts get-caller-identity
```

✅ **Expected:** JSON showing your account number and `user/techudaan-cli`.

> 🔐 Your keys are saved in `~/.aws/credentials`. **Never** put this file, or the keys, in Git, screenshots or chat messages.

---

## 6. Create the Cluster

### Option A: One command (simplest)

```bash
eksctl create cluster \
  --name techudaan \
  --region ap-south-1 \
  --nodegroup-name techudaan-nodes \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 2 \
  --managed
```

| Flag | Meaning |
|---|---|
| `--name techudaan` | Cluster name |
| `--region ap-south-1` | Create it in Mumbai |
| `--nodegroup-name` | Name of the worker node group |
| `--node-type t3.medium` | Each node: 2 vCPU, 4 GB RAM |
| `--nodes 2` | Start with 2 worker nodes |
| `--nodes-min 1 --nodes-max 2` | Allowed range if you scale the node group |
| `--managed` | Use a **managed** node group (EKS handles node updates) |

### Option B: A config file (the "infrastructure as code" way)

Save as **`eks-cluster.yaml`**:

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: techudaan
  region: ap-south-1

managedNodeGroups:
  - name: techudaan-nodes
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 1
    maxSize: 2
    volumeSize: 20          # GB of disk per node
```

Preview, then create:

```bash
eksctl create cluster -f eks-cluster.yaml --dry-run
eksctl create cluster -f eks-cluster.yaml
```

### What happens (15–20 minutes ☕)

eksctl creates two **CloudFormation stacks**:

1. `eksctl-techudaan-cluster`: the VPC, subnets, security groups and the EKS control plane
2. `eksctl-techudaan-nodegroup-techudaan-nodes`: the EC2 worker nodes

✅ The last line should look like:

```
[✓]  EKS cluster "techudaan" in "ap-south-1" region is ready
```

> 💡 While you wait: AWS Console → **CloudFormation** → watch the stacks being built. Every VPC, subnet and role appears as an event.

---

## 7. Connect kubectl

eksctl already added the cluster to your kubeconfig and switched to it:

```bash
kubectl config current-context
```

✅ Something like `techudaan-cli@techudaan.ap-south-1.eksctl.io`. That's long, so rename it:

```bash
kubectl config rename-context $(kubectl config current-context) eks-techudaan
```

**Lost the context?** (new laptop, deleted kubeconfig) Restore it with:

```bash
aws eks update-kubeconfig --name techudaan --region ap-south-1 --alias eks-techudaan
```

---

## 8. Explore Your EKS Cluster

```bash
kubectl get nodes -o wide
```

✅ 2 nodes, with names like `ip-192-168-xx-xx.ap-south-1.compute.internal`, OS **Amazon Linux**, runtime **containerd**.

```bash
kubectl get pods -n kube-system
```

✅ You'll see Pods such as `aws-node-xxxxx` (one per node), `coredns-...`, `kube-proxy-...` and possibly other add-ons.

✍️ **Compare with kind:**

| | kind | EKS |
|---|---|---|
| `kube-apiserver`, `etcd`, `kube-scheduler` Pods | ✅ Visible | ❌ **Hidden**: AWS runs them |
| CNI plugin | `kindnet` | `aws-node` (**Amazon VPC CNI**) |
| Pod IPs come from | A private Pod range | **Real VPC subnet IPs** |

Check that last point:

```bash
kubectl create deployment hello --image=nginx --replicas=2
kubectl get pods -o wide
```

The Pod IPs are in the same `192.168.x.x` range as the nodes. With the AWS VPC CNI, Pods get **real VPC IP addresses**.

---

## 9. Expose the App to the Internet

```bash
kubectl expose deployment hello --port=80 --type=LoadBalancer
kubectl get svc hello -w
```

After 1–3 minutes, `EXTERNAL-IP` shows a DNS name like `xxxx.ap-south-1.elb.amazonaws.com`. Press `Ctrl+C`.

```bash
LB=$(kubectl get svc hello -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "http://$LB"
curl -s http://$LB | head -4
```

> The DNS name can take another 2–3 minutes to start working. Retry if `curl` fails at first.

Open the URL in your browser: **"Welcome to nginx!"** from a real AWS load balancer. 🎉

**What just happened:** Kubernetes asked AWS (through its cloud integration) to create a **real load balancer** in your account. Check: AWS Console → **EC2** → **Load Balancers**.

> ⚠️ This load balancer costs money. Delete it in the next step.

---

## 10. Delete Everything 🧹

### Step 1: Delete the LoadBalancer Service first

```bash
kubectl delete service hello
kubectl delete deployment hello
```

Wait about 1 minute so AWS removes the load balancer.

### Step 2: Delete the cluster

```bash
eksctl delete cluster --name techudaan --region ap-south-1 --wait
```

This takes about 10–15 minutes and deletes the node group, the control plane and the VPC (both CloudFormation stacks).

### Step 3: Confirm nothing is left

```bash
eksctl get cluster --region ap-south-1
aws cloudformation list-stacks --region ap-south-1 \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE DELETE_FAILED \
  --query "StackSummaries[?contains(StackName,'eksctl-techudaan')].[StackName,StackStatus]" --output table
aws elb describe-load-balancers --region ap-south-1 --query "LoadBalancerDescriptions[].DNSName"
aws elbv2 describe-load-balancers --region ap-south-1 --query "LoadBalancers[].DNSName"
aws ec2 describe-volumes --region ap-south-1 --filters Name=status,Values=available --query "Volumes[].VolumeId"
```

✅ **Expected:** no clusters, no `eksctl-techudaan` stacks, and empty lists (`[]`) for load balancers and unattached volumes.

Clean up the kubeconfig entry:

```bash
kubectl config delete-context eks-techudaan
```

Finally, check **Billing → Bills** in the console over the next day.

---

## 11. Troubleshooting

| Problem | Fix |
|---|---|
| `Unable to locate credentials` | Run `aws configure`; check with `aws sts get-caller-identity` |
| `AccessDenied` / `not authorized to perform` | Your IAM user lacks permissions. Attach the needed policy (AdministratorAccess for learning) |
| Node group fails to create | Check AWS Console → **CloudFormation** → the nodegroup stack → **Events** for the real error |
| Error that the instance type isn't allowed (Free plan accounts) | The Free plan limits some services/instance types. Try a smaller type (e.g. `t3.small`), or upgrade the account to the Paid plan (credits still apply) |
| `UnsupportedAvailabilityZoneException` | Add `--zones ap-south-1a,ap-south-1b` to the create command |
| `error: You must be logged in to the server (Unauthorized)` | Run `aws eks update-kubeconfig ...`; make sure you're the same IAM user that created the cluster |
| `EXTERNAL-IP` stuck on `<pending>` | Wait 3 minutes; check `kubectl describe svc hello` → Events |
| `eksctl delete` fails with `DELETE_FAILED` | A load balancer or network interface is still attached. Delete leftover load balancers in EC2, then re-run the delete |

---

## ✅ Recap

- EKS = AWS runs the **control plane**; your **nodes are EC2 instances** in your VPC.
- `eksctl` creates the VPC, control plane and node group with **one command** (via CloudFormation).
- The control plane is charged per hour, plus nodes, disks and load balancers. **Delete LoadBalancer Services first, then the cluster, then verify.**

➡️ Next: [03. Azure AKS](03-azure-aks.md)
