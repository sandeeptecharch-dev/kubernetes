# Day 5: Clusters, Nodes and Namespaces 🏢

> Understand the three "containers" everything in Kubernetes lives in: the **cluster**, its **nodes** (physical) and its **namespaces** (logical). Then manage nodes like an operator and split one cluster into safe, separate environments.

⏱️ **Time:** about 90 minutes · 💰 **Cost:** free · 🎯 **Level:** beginner

🏠 [Course home](../README.md) · ⬅️ [Day 4: kind & kubectl](../module-04-kind-kubectl/README.md) · 📋 [Cheat sheet](../cheatsheets/kind-cluster-context.md)

---

## 1. The Big Picture

### The campus analogy 🏫

Think of a company **campus**:

| Kubernetes | Campus | Physical or logical? |
|---|---|---|
| **Cluster** | The whole campus | Everything together |
| **Node** | A building on the campus | **Physical**: real machines (or VMs) |
| **Namespace** | A department (HR, Finance, Engineering) | **Logical**: a way of organising and dividing up |

Here's the key insight 💡: **a department's people can sit in any building.** In the same way, a namespace is **not** tied to a node. Pods from namespace `dev` can run on every node, side by side with Pods from `prod`.

```
                         CLUSTER "techudaan"
 ┌──────────────────────────────────────────────────────────────────┐
 │   NODES (physical)                                               │
 │   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
 │   │ control-plane   │  │ worker          │  │ worker2         │  │
 │   │                 │  │ [dev] web-1     │  │ [dev] web-2     │  │
 │   │ [kube-system]   │  │ [prod] web-1    │  │ [prod] web-2    │  │
 │   │  apiserver,etcd │  │ [kube-system]   │  │ [kube-system]   │  │
 │   └─────────────────┘  └─────────────────┘  └─────────────────┘  │
 │                                                                  │
 │   NAMESPACES (logical, span ALL nodes)                           │
 │   default · kube-system · kube-public · kube-node-lease          │
 │   dev · staging · prod   ← created by you                        │
 └──────────────────────────────────────────────────────────────────┘
```

### Node vs Namespace: the #1 beginner confusion

| | **Node** | **Namespace** |
|---|---|---|
| What is it? | A machine that runs Pods | A named group of objects |
| Physical? | ✅ Yes (VM, server, or a kind container) | ❌ No, just a label for organising |
| Used for | Providing CPU and memory | Separating teams, apps, environments |
| A Pod belongs to | Exactly one node (where it runs) | Exactly one namespace (where it's managed) |
| Limit resources with | Node size, taints | **ResourceQuota**, **LimitRange** |

### Namespaced vs cluster-scoped objects

| **Namespaced** (live inside a namespace) | **Cluster-scoped** (belong to the whole cluster) |
|---|---|
| Pods, Deployments, Services, ConfigMaps, Secrets, ResourceQuotas | **Nodes**, **Namespaces**, PersistentVolumes, StorageClasses, ClusterRoles |

> A node isn't "in" a namespace, and a namespace isn't "in" another namespace. Both are cluster-wide.

---

## Files in This Folder

```
module-05-clusters-nodes-namespaces/
├── README.md                  ← you are here
├── kind-configs/
│   └── kind-labeled.yaml      ← 3-node cluster with labelled workers
├── manifests/
│   ├── namespaces.yaml        ← dev, staging, prod
│   ├── web-app.yaml           ← Deployment + Service, deployable to any namespace
│   ├── resource-quota.yaml    ← a "budget" for the dev namespace
│   └── limit-range.yaml       ← default container sizes for dev
└── scripts/
    └── node-report.sh         ← one-screen report of every node
```

> 💡 Run every command from this folder: `cd techudaan-kubernetes/module-05-clusters-nodes-namespaces`

---

## Labs Overview

| Lab | Topic | Time |
|---|---|---|
| [0](#lab-0-create-the-cluster) | Create the cluster | 5 min |
| [1](#lab-1-explore-the-cluster) | Explore the cluster | 10 min |
| [2](#lab-2-nodes-up-close) | Nodes up close: status, capacity, labels | 15 min |
| [3](#lab-3-node-maintenance-cordon-drain-uncordon) | Node maintenance: cordon, drain, uncordon | 10 min |
| [4](#lab-4-namespaces-basics) | Namespaces basics | 15 min |
| [5](#lab-5-talking-across-namespaces) | Talking across namespaces (DNS) | 5 min |
| [6](#lab-6-give-a-namespace-a-budget-resourcequota--limitrange) | Give a namespace a budget: ResourceQuota + LimitRange | 20 min |
| [7](#lab-7-deleting-a-namespace) | Deleting a namespace (the dangerous one) | 5 min |
| [8](#lab-8-clean-up) | Clean up | 2 min |

---

## Lab 0: Create the Cluster

```bash
kind create cluster --name techudaan --config kind-configs/kind-labeled.yaml
kubectl get nodes
```

✅ 3 nodes, all `Ready`.

> Already have the `techudaan` cluster from Day 4? Keep it; you'll add the labels by hand in Lab 2.

---

## Lab 1: Explore the Cluster

### Step 1: Which cluster am I in?

```bash
kubectl config current-context
kubectl cluster-info
kubectl version
```

### Step 2: What belongs to the whole cluster vs to a namespace?

```bash
kubectl api-resources --namespaced=false | head -20
kubectl api-resources --namespaced=true  | head -20
```

✅ `nodes` and `namespaces` appear in the **first** list (cluster-scoped). `pods`, `deployments`, `services` appear in the **second** (namespaced).

### Step 3: Count everything running in the cluster

```bash
kubectl get pods -A
kubectl get pods -A --no-headers | wc -l
```

✍️ **Write down:** how many Pods run in your "empty" cluster? Which namespace are they in?

---

## Lab 2: Nodes Up Close

### Step 1: The quick view

```bash
kubectl get nodes -o wide
```

| Column | Meaning |
|---|---|
| `STATUS` | `Ready` = the kubelet is healthy and reporting |
| `ROLES` | `control-plane` or `<none>` (a worker with no role label) |
| `INTERNAL-IP` | The node's IP on the cluster network |
| `OS-IMAGE`, `KERNEL-VERSION` | The node's operating system |
| `CONTAINER-RUNTIME` | e.g. `containerd://...` |

### Step 2: The node report

```bash
bash scripts/node-report.sh
```

✅ One line per node: Ready, roles, schedulable or cordoned, CPU, memory, Pod count and taints.

### Step 3: Read a node's full story

```bash
kubectl describe node techudaan-worker
```

Find these sections:

| Section | What it tells you |
|---|---|
| `Labels` | Key=value tags describing the node |
| `Taints` | "Keep away" signs for Pods (empty on workers) |
| `Conditions` | `MemoryPressure`, `DiskPressure`, `PIDPressure`, `Ready` |
| `Capacity` | Total CPU/memory of the machine |
| `Allocatable` | What's left for **Pods** after system reserves |
| `Non-terminated Pods` | Every Pod running on this node right now |
| `Allocated resources` | How much of Allocatable is already **requested** |

> 💡 The scheduler uses **Allocatable** minus **already requested**, not the machine's total.

### Step 4: Node labels

```bash
kubectl get nodes --show-labels
kubectl get nodes -L tier,disk
```

Used the Day 4 cluster (no labels)? Add them now:

```bash
kubectl label node techudaan-worker  tier=frontend disk=ssd
kubectl label node techudaan-worker2 tier=backend  disk=hdd
```

Give the workers a proper **role** so `ROLES` doesn't say `<none>`:

```bash
kubectl label node techudaan-worker  node-role.kubernetes.io/worker=
kubectl label node techudaan-worker2 node-role.kubernetes.io/worker=
kubectl get nodes
```

✅ `ROLES` now shows `worker`.

### Step 5: Filter nodes by label

```bash
kubectl get nodes -l disk=ssd
kubectl get nodes -l 'tier in (frontend,backend)'
kubectl get nodes -l '!node-role.kubernetes.io/control-plane'
```

### Step 6: Send a Pod to a labelled node

```bash
kubectl run fast --image=nginx --overrides='{"spec":{"nodeSelector":{"disk":"ssd"}}}'
kubectl get pod fast -o wide
kubectl delete pod fast
```

✅ It always lands on the `disk=ssd` node.

---

## Lab 3: Node Maintenance: Cordon, Drain, Uncordon

Real situation: a node needs an OS update. You must move its Pods away safely first.

### Step 1: Deploy something to move

```bash
kubectl create deployment demo --image=nginx --replicas=6
kubectl get pods -l app=demo -o wide
```

### Step 2: Cordon: no **new** Pods here

```bash
kubectl cordon techudaan-worker
kubectl get nodes
```

✅ `techudaan-worker` shows `Ready,SchedulingDisabled`. Existing Pods stay; new ones avoid it.

### Step 3: Drain: move the existing Pods away

```bash
kubectl drain techudaan-worker --ignore-daemonsets --delete-emptydir-data
kubectl get pods -l app=demo -o wide
```

✅ All 6 `demo` Pods now run on `techudaan-worker2`.

| Flag | Why |
|---|---|
| `--ignore-daemonsets` | DaemonSet Pods (kube-proxy, CNI) must stay on every node, so drain skips them |
| `--delete-emptydir-data` | Allows evicting Pods that use temporary `emptyDir` storage |

### Step 4: "Maintenance done": uncordon

```bash
kubectl uncordon techudaan-worker
kubectl get nodes
bash scripts/node-report.sh
```

> 💡 Kubernetes does **not** move Pods back automatically. Only new Pods will use the node again.

```bash
kubectl delete deployment demo
```

---

## Lab 4: Namespaces Basics

### Step 1: The 4 built-in namespaces

```bash
kubectl get namespaces
```

| Namespace | What lives there |
|---|---|
| `default` | Your stuff, when you don't say a namespace |
| `kube-system` | Kubernetes' own components (CoreDNS, kube-proxy, …) |
| `kube-public` | Readable by everyone; rarely used |
| `kube-node-lease` | Node heartbeats (Lease objects, from the kubelet) |

### Step 2: Create namespaces two ways

Imperative:

```bash
kubectl create namespace scratch
```

Declarative (better: it's a file you can keep in Git):

```bash
cat manifests/namespaces.yaml
kubectl apply -f manifests/namespaces.yaml
kubectl get namespaces --show-labels
```

### Step 3: Same app, same name, different namespaces

```bash
kubectl apply -f manifests/web-app.yaml -n dev
kubectl apply -f manifests/web-app.yaml -n prod
kubectl get deployments -A | grep -E "NAMESPACE|web"
```

✅ Two Deployments both called `web`, no clash. They're in different namespaces.

### Step 4: `-n` and `-A`

```bash
kubectl get pods                 # default namespace: nothing!
kubectl get pods -n dev          # dev only
kubectl get pods -A -l app=web -o wide   # all namespaces: notice dev and prod Pods share nodes
```

✍️ **Look at the `NODE` column:** dev and prod Pods run on the **same** nodes. Namespaces are logical, not physical.

### Step 5: Change your default namespace

```bash
kubectl config set-context --current --namespace=dev
kubectl get pods                 # now shows dev
kubectl config view --minify -o jsonpath='{..namespace}{"\n"}'
kubectl config set-context --current --namespace=default
```

> ⚠️ Forgetting which namespace you're in is a classic mistake. Check it before deleting anything.

---

## Lab 5: Talking Across Namespaces

Each Service gets a DNS name: `<service>.<namespace>.svc.cluster.local`

```bash
kubectl run client -n dev --image=busybox:1.36 --rm -it --restart=Never -- \
  sh -c "wget -qO- -T 3 web | head -4; echo '---'; wget -qO- -T 3 web.prod | head -4"
```

✅ Both work:
- `web` → the `web` Service in **dev** (same namespace as the client)
- `web.prod` → the `web` Service in **prod**

> 💡 Namespaces separate **names**, not **network traffic**. Pods in different namespaces can still talk unless a **NetworkPolicy** blocks it (a later module).

---

## Lab 6: Give a Namespace a Budget: ResourceQuota + LimitRange

Real situation: the dev team keeps launching huge test apps and slowing down everyone else. Give `dev` a budget.

### Step 1: Start fresh in dev

```bash
kubectl delete -f manifests/web-app.yaml -n dev
```

### Step 2: Apply the quota

```bash
cat manifests/resource-quota.yaml
kubectl apply -f manifests/resource-quota.yaml
kubectl describe resourcequota dev-quota -n dev
```

✅ A table of `Used` vs `Hard` limits: at most 5 Pods, 1 CPU requested, and so on.

### Step 3: Deploy the app, and watch it fail 😮

```bash
kubectl apply -f manifests/web-app.yaml -n dev
kubectl get deployment web -n dev
kubectl get pods -n dev
```

✅ The Deployment exists, but **0 Pods**. Find out why:

```bash
kubectl describe replicaset -n dev -l app=web | grep -A3 -i "warning"
```

You'll see `FailedCreate` with a message like `must specify limits.cpu ... requests.cpu ...`.

**Why?** Once a quota limits CPU/memory, Kubernetes must know **how much** each Pod wants, to check it against the budget. `web-app.yaml` doesn't say, so every Pod is rejected.

### Step 4: Fix it with default sizes (LimitRange)

```bash
cat manifests/limit-range.yaml
kubectl apply -f manifests/limit-range.yaml
kubectl delete -f manifests/web-app.yaml -n dev
kubectl apply  -f manifests/web-app.yaml -n dev
kubectl get pods -n dev
```

✅ 3 Pods running. Check the requests that were added automatically:

```bash
kubectl get pod -n dev -l app=web -o jsonpath='{.items[0].spec.containers[0].resources}{"\n"}'
kubectl describe resourcequota dev-quota -n dev
```

✅ `requests.cpu` shows `300m` used (3 Pods × 100m).

### Step 5: Hit the ceiling

```bash
kubectl scale deployment web -n dev --replicas=8
kubectl get pods -n dev
kubectl describe resourcequota dev-quota -n dev
kubectl describe replicaset -n dev -l app=web | grep -i "exceeded quota" | head -2
```

✅ Only **5** Pods run (quota: `pods: "5"`). The events say `exceeded quota`.

### Step 6: Prove prod is unaffected

```bash
kubectl scale deployment web -n prod --replicas=8
kubectl get pods -n prod
```

✅ 8 Pods in prod. The quota only applies to `dev`.

```bash
kubectl scale deployment web -n prod --replicas=3
```

---

## Lab 7: Deleting a Namespace

> ⚠️ Deleting a namespace deletes **everything inside it**: Deployments, Pods, Services, Secrets, quotas. There is no undo.

```bash
kubectl apply -f manifests/web-app.yaml -n staging
kubectl get all -n staging
kubectl delete namespace staging
kubectl get all -n staging
kubectl get namespaces
```

✅ Everything in `staging` is gone, and the namespace too.

> In real jobs, protect production namespaces with RBAC so most people **can't** delete them.

---

## Lab 8: Clean Up

```bash
kubectl delete namespace dev prod scratch
kubectl config set-context --current --namespace=default
kubectl get namespaces
```

Keep the cluster for the next module, or delete it:

```bash
kind delete cluster --name techudaan
```

---

## 🏆 Challenges (Optional)

1. **Team quota:** create a namespace `payments` with a quota of max **3 Pods** and **2 Services**. Prove both limits work.
2. **Node detective:** using only `kubectl`, find which node has the **most** Pods. (Hint: `--field-selector spec.nodeName=...`, or `node-report.sh`.)
3. **Max size:** in `dev`, try to run a container requesting `cpu: 1`. What does the LimitRange say?
4. **Context per environment:** create a kubectl context `techudaan-dev` that uses the `techudaan` cluster with default namespace `dev`. (Hint: `kubectl config set-context ... --namespace=dev` and the cheat sheet.)

---

## 🧯 Troubleshooting

| Problem | Cause / Fix |
|---|---|
| `kubectl get pods` shows nothing, but you deployed something | You're in a different namespace. Use `-n <ns>` or `-A` |
| `error: ... unknown field "labels"` creating the kind cluster | Older kind version. Use Day 4's `kind-3node.yaml` and label nodes by hand |
| Deployment shows `0/3` ready in a quota'd namespace | Pods lack requests/limits. Add a LimitRange or set `resources:` |
| `exceeded quota` events | The namespace hit its budget. Scale down or raise the quota |
| `drain` stuck or erroring on Pods | Add `--ignore-daemonsets --delete-emptydir-data`; Pods with no controller need `--force` |
| Namespace stuck in `Terminating` | Something inside can't be deleted (often a finalizer). `kubectl get all -n <ns>` and investigate |

---

## 🧩 Self-Check Quiz

1. Is a namespace tied to a specific node?
2. Name the 4 namespaces every cluster starts with.
3. Are Nodes namespaced or cluster-scoped?
4. What's the difference between `cordon` and `drain`?
5. A namespace has a ResourceQuota on CPU. You deploy an app with no `resources:`. What happens, and how do you fix it?
6. From namespace `dev`, what name reaches Service `web` in namespace `prod`?
7. What happens to Pods when you delete their namespace?

<details>
<summary>Answers</summary>

1. No. Namespaces are logical; their Pods can run on any node.
2. `default`, `kube-system`, `kube-public`, `kube-node-lease`.
3. Cluster-scoped.
4. `cordon` stops new Pods being scheduled there; `drain` cordons **and** evicts the existing Pods.
5. The Pods are rejected (`must specify requests/limits`). Add a LimitRange with defaults, or set `resources:` in the Pod spec.
6. `web.prod` (or `web.prod.svc.cluster.local`).
7. They're deleted, along with everything else in the namespace.

</details>

---

## 🎤 Interview Questions

- What's the difference between a node and a namespace?
- How would you stop one team from using all the cluster's resources?
- Walk me through safely patching a worker node's OS.
- Do namespaces isolate network traffic? What does?

---

➡️ **Next:** Day 6, your first Pod, written by hand (Module 2: Pods).
