# Cheat Sheet: kind, Cluster and Context Commands 📋

> Every command you need to create clusters, switch between them, and inspect them. Keep this page open while you work.

🏠 [Back to course home](../README.md) | 🛠️ [Setup guide](../module-00-setup/README.md)

---

## Contents

1. [Key ideas: cluster, context, kubeconfig](#1-key-ideas-cluster-context-kubeconfig)
2. [kind commands](#2-kind-commands)
3. [Context and kubeconfig commands](#3-context-and-kubeconfig-commands)
4. [Cluster information commands](#4-cluster-information-commands)
5. [Node commands](#5-node-commands)
6. [Namespace commands](#6-namespace-commands)
7. [Ready-made kind configs](#7-ready-made-kind-configs)
8. [Practice: two clusters, one kubectl](#8-practice-two-clusters-one-kubectl)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Key Ideas: Cluster, Context, kubeconfig

Before the commands, understand these 3 words. They confuse everyone at first.

| Word | Meaning | Railway analogy |
|---|---|---|
| **Cluster** | A Kubernetes installation: an API server address + its certificate | A railway zone (e.g. Western Railway) |
| **User** | The credentials kubectl uses to log in | Your staff ID card |
| **Context** | A saved combination: **cluster + user + default namespace** | "I am working in Western Railway, with my ID, at Mumbai division" |
| **kubeconfig** | The file that stores all clusters, users and contexts | Your diary with every zone's contact details |
| **Current context** | The context kubectl uses right now | The zone you're currently working in |

The kubeconfig file lives at **`~/.kube/config`** by default:

```
~/.kube/config
├── clusters:          ← where (API server address + CA certificate)
│   ├── kind-techudaan
│   └── kind-dev
├── users:             ← who (client certificate / token)
│   ├── kind-techudaan
│   └── kind-dev
├── contexts:          ← cluster + user + namespace, with a name
│   ├── kind-techudaan
│   └── kind-dev
└── current-context: kind-techudaan   ← what kubectl uses NOW
```

> 💡 **kind naming rule:** a kind cluster named `techudaan` creates a context named **`kind-techudaan`**. kind adds the `kind-` prefix automatically.

> ⚠️ **The #1 beginner mistake** (and a real production danger): running a command against the **wrong cluster**. Always check `kubectl config current-context` before changing anything important.

---

## 2. kind Commands

### Create clusters

| Command | What it does |
|---|---|
| `kind create cluster` | Creates a 1-node cluster named `kind` (context `kind-kind`) |
| `kind create cluster --name techudaan` | Creates a cluster with your chosen name |
| `kind create cluster --name techudaan --config kind-3node.yaml` | Creates a cluster from a config file (multi-node, ports, etc.) |
| `kind create cluster --name old --image kindest/node:<version>` | Creates a cluster running a specific Kubernetes version* |
| `kind create cluster --name techudaan --wait 2m` | Waits until the control plane is ready before returning |
| `kind create cluster --name techudaan --kubeconfig ./my-kubeconfig` | Writes access details to a separate file instead of `~/.kube/config` |

\* Each kind release lists its supported `kindest/node` images (with exact tags) on the [kind releases page](https://github.com/kubernetes-sigs/kind/releases). Copy the tag from there.

### List and inspect

| Command | What it does |
|---|---|
| `kind get clusters` | Lists all kind clusters on this machine |
| `kind get nodes --name techudaan` | Lists the node containers of one cluster |
| `docker ps --filter "label=io.x-k8s.kind.cluster=techudaan"` | Shows the Docker containers behind that cluster |
| `kind version` | Shows the kind version |

### Access (kubeconfig)

| Command | What it does |
|---|---|
| `kind get kubeconfig --name techudaan` | Prints the cluster's kubeconfig to the screen |
| `kind get kubeconfig --name techudaan > techudaan.kubeconfig` | Saves it to a file (e.g. to share with a teammate's tools) |
| `kind export kubeconfig --name techudaan` | Re-adds the cluster to `~/.kube/config` **and makes it current** (fixes a lost or deleted context) |

### Images and logs

| Command | What it does |
|---|---|
| `kind load docker-image myapp:1.0 --name techudaan` | Copies a locally built image into every node, so Pods can use it **without a registry** |
| `kind load image-archive myapp.tar --name techudaan` | Same, from a saved `.tar` image file |
| `kind export logs ./kind-logs --name techudaan` | Saves all node, kubelet and container logs into a folder, for debugging |

> 💡 **Using your own image?** After `kind load docker-image`, set `imagePullPolicy: IfNotPresent` (or `Never`) in your Pod spec, and **don't** use the `:latest` tag. Otherwise Kubernetes tries to pull from Docker Hub and fails.

### Delete

| Command | What it does |
|---|---|
| `kind delete cluster --name techudaan` | Deletes one cluster and removes its context from kubeconfig |
| `kind delete cluster` | Deletes the cluster named `kind` (the default name) |
| `kind delete clusters --all` | Deletes **every** kind cluster on this machine |
| `kind delete clusters dev test` | Deletes several clusters by name |

### Get inside a node

Each kind node is a Docker container, so you can open a shell on it:

| Command | What it does |
|---|---|
| `docker exec -it techudaan-control-plane bash` | Shell on the control-plane node |
| `docker exec -it techudaan-worker bash` | Shell on a worker node |
| `docker exec techudaan-worker crictl ps` | Run one command on a node without a shell |

---

## 3. Context and kubeconfig Commands

### See where you are

| Command | What it does |
|---|---|
| `kubectl config current-context` | Shows the context kubectl is using **right now** |
| `kubectl config get-contexts` | Lists all contexts; `*` marks the current one |
| `kubectl config get-clusters` | Lists all clusters in kubeconfig |
| `kubectl config get-users` | Lists all users in kubeconfig |
| `kubectl config view` | Shows the whole kubeconfig (certificates hidden) |
| `kubectl config view --minify` | Shows **only** the current context's cluster, user and namespace |
| `kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'` | Prints the API server address you're connected to |
| `kubectl config view --raw` | Shows everything, **including secret certificates**. Never share this output |

### Switch

| Command | What it does |
|---|---|
| `kubectl config use-context kind-techudaan` | Switches kubectl to another cluster |
| `kubectl get pods --context kind-dev` | Runs **one** command against another cluster, without switching |
| `kubectl config set-context --current --namespace=shop` | Changes the default namespace of the current context |
| `kubectl config view --minify -o jsonpath='{..namespace}'` | Shows the current default namespace (empty = `default`) |

### Manage

| Command | What it does |
|---|---|
| `kubectl config rename-context kind-techudaan lab` | Renames a context (e.g. shorter names) |
| `kubectl config set-context dev-shop --cluster=kind-dev --user=kind-dev --namespace=shop` | Creates a new context from an existing cluster and user |
| `kubectl config delete-context kind-old` | Removes a context from kubeconfig |
| `kubectl config delete-cluster kind-old` | Removes a cluster entry from kubeconfig |
| `kubectl config delete-user kind-old` | Removes a user entry from kubeconfig |
| `kubectl config unset current-context` | Clears the current context, so nothing runs by accident |

> ⚠️ Deleting a **context** only removes the saved shortcut. It does **not** delete the cluster. Use `kind delete cluster` for that.

### Work with several kubeconfig files

| Command | What it does |
|---|---|
| `kubectl get nodes --kubeconfig ./techudaan.kubeconfig` | Uses a specific kubeconfig file for one command |
| `export KUBECONFIG=./techudaan.kubeconfig` | Uses that file for the rest of this terminal session |
| `export KUBECONFIG=~/.kube/config:./other.kubeconfig` | Merges several files (use `;` instead of `:` on Windows PowerShell) |
| `kubectl config view --flatten > merged.kubeconfig` | Saves the merged result as one file |
| `unset KUBECONFIG` | Goes back to the default `~/.kube/config` |

> 💡 **Back up first:** `cp ~/.kube/config ~/.kube/config.backup` before editing or merging.

### Optional helpers: kubectx and kubens

Faster switching for people with many clusters:

| Command | Same as |
|---|---|
| `kubectx` | `kubectl config get-contexts` |
| `kubectx kind-dev` | `kubectl config use-context kind-dev` |
| `kubectx -` | Switch back to the previous context |
| `kubens shop` | `kubectl config set-context --current --namespace=shop` |

Install: `brew install kubectx` (macOS) or see [github.com/ahmetb/kubectx](https://github.com/ahmetb/kubectx).

---

## 4. Cluster Information Commands

| Command | What it shows |
|---|---|
| `kubectl cluster-info` | The API server and CoreDNS addresses |
| `kubectl cluster-info dump > dump.txt` | A huge debug dump of the whole cluster's state |
| `kubectl version` | Client (kubectl) and server (cluster) versions |
| `kubectl get --raw='/readyz?verbose'` | API server health checks, one by one |
| `kubectl get --raw='/livez'` | Is the API server alive? (prints `ok`) |
| `kubectl get nodes` | All nodes and their status |
| `kubectl get nodes -o wide` | Plus IPs, OS, kernel and container runtime |
| `kubectl get pods -A` | Every Pod in every namespace |
| `kubectl get pods -n kube-system -o wide` | The cluster's own components |
| `kubectl get all -A` | Common resources across all namespaces |
| `kubectl get events -A --sort-by=.metadata.creationTimestamp` | Recent events, newest last: the cluster's "news feed" |
| `kubectl get events -A --field-selector type=Warning` | Only warnings |
| `kubectl api-resources` | Every resource type the cluster supports |
| `kubectl api-versions` | Every API group/version available |
| `kubectl explain deployment.spec` | Built-in docs for any field |
| `kubectl top nodes` / `kubectl top pods -A` | CPU and memory use (needs **metrics-server**) |

> ℹ️ `kubectl get componentstatuses` is deprecated. Use `kubectl get --raw='/readyz?verbose'` and `kubectl get pods -n kube-system` instead.

---

## 5. Node Commands

| Command | What it does |
|---|---|
| `kubectl describe node techudaan-worker` | Full details: conditions, capacity, Pods, events |
| `kubectl get nodes --show-labels` | Nodes with all their labels |
| `kubectl get nodes -o custom-columns=NODE:.metadata.name,PODS:.spec.podCIDR` | Each node's Pod IP range |
| `kubectl label node techudaan-worker2 disk=ssd` | Adds a label |
| `kubectl label node techudaan-worker2 disk-` | Removes that label (note the `-`) |
| `kubectl taint node techudaan-worker maint=true:NoSchedule` | Repels new Pods without a matching toleration |
| `kubectl taint node techudaan-worker maint=true:NoSchedule-` | Removes the taint |
| `kubectl cordon techudaan-worker` | Stops **new** Pods being scheduled on the node |
| `kubectl drain techudaan-worker --ignore-daemonsets --delete-emptydir-data` | Cordons the node **and** moves its Pods away (before maintenance) |
| `kubectl uncordon techudaan-worker` | Allows scheduling on the node again |

> 💡 Maintenance pattern: **drain → do the work → uncordon**.

---

## 6. Namespace Commands

| Command | What it does |
|---|---|
| `kubectl get namespaces` | Lists namespaces |
| `kubectl create namespace shop` | Creates a namespace |
| `kubectl get pods -n shop` | Pods in one namespace |
| `kubectl config set-context --current --namespace=shop` | Makes `shop` the default for this context |
| `kubectl config set-context --current --namespace=default` | Switches back to `default` |
| `kubectl delete namespace shop` | Deletes the namespace **and everything inside it** ⚠️ |

---

## 7. Ready-Made kind Configs

Save any of these as a `.yaml` file and create the cluster with:

```bash
kind create cluster --name <name> --config <file>.yaml
```

### 7a. The course cluster: 1 control plane + 2 workers

```yaml
# kind-3node.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

### 7b. Light cluster for 8 GB laptops: 1 control plane + 1 worker

```yaml
# kind-2node.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
```

### 7c. Reach apps from your browser (port mapping)

Maps port 30080 on your laptop to the same NodePort on the cluster. Open `http://localhost:30080` after exposing a NodePort Service on port 30080.

```yaml
# kind-ports.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 30080
        protocol: TCP
  - role: worker
```

Try it:

```bash
kind create cluster --name ports --config kind-ports.yaml
kubectl create deployment web --image=nginx
kubectl create service nodeport web --tcp=80:80 --node-port=30080
curl http://localhost:30080
```

### 7d. High availability: 3 control planes + 2 workers

Like production. Needs more RAM (16 GB recommended).

```yaml
# kind-ha.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: control-plane
  - role: control-plane
  - role: worker
  - role: worker
```

kind adds a load balancer container in front of the 3 API servers automatically. Check with `docker ps`.

### 7e. A cluster without a CNI plugin (for the CNI lesson)

```yaml
# kind-no-cni.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
nodes:
  - role: control-plane
```

Nodes stay `NotReady` until you install a CNI plugin.

---

## 8. Practice: Two Clusters, One kubectl

⏱️ About 15 minutes. This is how engineers work with **dev** and **prod** clusters every day.

**1. Create two clusters**

```bash
kind create cluster --name dev
kind create cluster --name prod
kind get clusters
```

**2. See both contexts.** Which one is current, and why?

```bash
kubectl config get-contexts
kubectl config current-context
```

✅ `kind-prod` is current, because kind switches to the **most recently created** cluster.

**3. Deploy only to dev**

```bash
kubectl config use-context kind-dev
kubectl create deployment hello --image=nginx
kubectl get deployments
```

**4. Check prod without switching**

```bash
kubectl get deployments --context kind-prod
```

✅ `No resources found`. The clusters are completely separate.

**5. Give contexts friendlier names**

```bash
kubectl config rename-context kind-dev dev
kubectl config rename-context kind-prod prod
kubectl config get-contexts
```

**6. Set a default namespace in dev**

```bash
kubectl config use-context dev
kubectl create namespace shop
kubectl config set-context --current --namespace=shop
kubectl create deployment cart --image=nginx
kubectl get deployments                      # shows cart (namespace shop)
kubectl get deployments -n default           # shows hello
kubectl config set-context --current --namespace=default
```

**7. Show the current context in your prompt (optional but very useful)**

```bash
echo 'PS1="[\$(kubectl config current-context 2>/dev/null)] $PS1"' >> ~/.bashrc
source ~/.bashrc
```

Now your prompt always shows which cluster you're about to change.

**8. Clean up**

```bash
kind delete clusters dev prod
kubectl config delete-context dev 2>/dev/null
kubectl config delete-context prod 2>/dev/null
kubectl config use-context kind-techudaan
```

> 💡 After renaming, kind can't find the old context names to remove them on delete, which is why step 8 deletes them by hand.

**✍️ Questions to answer:**
1. Which command shows the cluster you're about to change?
2. What's the difference between `use-context` and `--context`?
3. Does deleting a context delete the cluster?

---

## 9. Troubleshooting

| Problem | Fix |
|---|---|
| `The connection to the server localhost:8080 was refused` | No current context set. Run `kubectl config get-contexts`, then `use-context` |
| `context "kind-x" does not exist` | Check spelling with `kubectl config get-contexts`; or restore it with `kind export kubeconfig --name x` |
| `ERROR: failed to create cluster: node(s) already exist for a cluster with the name "x"` | That name is taken. Use another, or `kind delete cluster --name x` first |
| Cluster gone after a laptop restart / Docker restart | `docker ps -a` to check the containers; otherwise delete and recreate it |
| Commands go to the wrong cluster | `kubectl config current-context`, then switch. Add the context to your prompt (section 8, step 7) |
| `ErrImagePull` for your own image | Run `kind load docker-image <image> --name <cluster>`, avoid `:latest`, set `imagePullPolicy: IfNotPresent` |
| `kubectl top` says `Metrics API not available` | metrics-server isn't installed (not included by kind) |
| `port is already allocated` when creating a cluster with ports | Another program or cluster uses that `hostPort`. Pick another port |

---

## ⚡ The 10 Commands You'll Use Every Day

```bash
kind get clusters                                    # which clusters exist?
kubectl config get-contexts                          # which contexts exist?
kubectl config current-context                       # where am I?
kubectl config use-context kind-techudaan            # go to the course cluster
kubectl config set-context --current --namespace=X   # change default namespace
kubectl cluster-info                                 # is the cluster reachable?
kubectl get nodes -o wide                            # are the nodes healthy?
kubectl get pods -A                                  # what's running everywhere?
kubectl get events -A --sort-by=.metadata.creationTimestamp   # what just happened?
kind delete cluster --name X                         # throw it away and start fresh
```
