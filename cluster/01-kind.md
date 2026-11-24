# 01. Create a Cluster with kind (Local, Free) 💻

> Build a real multi-node Kubernetes cluster on your own laptop in about 2 minutes, for free.

⬅️ [Cluster setup home](README.md) | ➡️ Next: [02. AWS EKS](02-aws-eks.md)

---

## 1. What Is kind?

**kind** = **K**ubernetes **IN** **D**ocker.

Normally a Kubernetes node is a whole machine (physical or virtual). kind cheats cleverly: each **node is a Docker container**, and inside each container runs everything a real node needs (kubelet, containerd, and for the control plane: API server, etcd, scheduler, controller manager).

```
Your laptop
└── Docker
    ├── container: techudaan-control-plane   ← a whole Kubernetes control-plane node
    ├── container: techudaan-worker          ← a whole worker node
    └── container: techudaan-worker2         ← another worker node
            └── inside: kubelet + containerd + your Pods
```

| ✅ Good for | ❌ Not for |
|---|---|
| Learning and practising | Running real production apps |
| Testing YAML before deploying it to a real cluster | Exposing apps to the internet |
| CI pipelines (fast throwaway clusters) | Long-running workloads |
| Breaking things safely | |

kind is an official Kubernetes project (`kubernetes-sigs`), and it's what Kubernetes developers use to test Kubernetes itself.

---

## 2. Before You Start

You need **Docker**, **kubectl** and **kind** installed. If you haven't done this yet, follow **[Module 0: Setup](../module-00-setup/README.md)**, then come back.

Quick check:

```bash
docker info > /dev/null && echo "Docker OK"
kubectl version --client
kind version
```

All three should work without errors.

---

## 3. Your First Cluster: 1 Node

```bash
kind create cluster --name hello
```

**What happens, step by step:**

| Output line | What kind is doing |
|---|---|
| `Ensuring node image (kindest/node:...)` | Downloads the node image (around 1 GB, only the first time) |
| `Preparing nodes` | Starts a Docker container to be the node |
| `Writing configuration` | Prepares Kubernetes config inside the node |
| `Starting control-plane` | Runs kubeadm to start the API server, etcd, scheduler, controller manager |
| `Installing CNI` | Installs the network plugin (kindnet) |
| `Installing StorageClass` | Adds local storage support for volumes |
| `Set kubectl context to "kind-hello"` | Points your `kubectl` at this new cluster |

Check it:

```bash
kubectl get nodes
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
```

✅ **Expected:** one node `hello-control-plane` (`Ready`), and one Docker container with the same name.

**What this proves:** a "node" here is literally a Docker container.

With a single node, the control plane also runs your apps. That's fine for a quick test, but our course uses 3 nodes, so delete this one:

```bash
kind delete cluster --name hello
```

---

## 4. The Course Cluster: 3 Nodes

### Step 1: Write the cluster config

Save this as **`kind-3node.yaml`** (it's also in [`module-01-architecture/kind-3node.yaml`](../module-01-architecture/kind-3node.yaml)):

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

| Line | Meaning |
|---|---|
| `kind: Cluster` | This file describes a whole cluster |
| `apiVersion: kind.x-k8s.io/v1alpha4` | The version of kind's config format |
| `nodes:` | The list of nodes to create |
| `- role: control-plane` | One node runs the brain |
| `- role: worker` (×2) | Two nodes run your apps |

> 💡 8 GB laptop struggling? Delete one `- role: worker` line for a 2-node cluster.

### Step 2: Create it

```bash
kind create cluster --name techudaan --config kind-3node.yaml
```

### Step 3: Verify

```bash
kind get clusters
kubectl config current-context
kubectl cluster-info
kubectl get nodes -o wide
```

✅ **Expected:**

```
NAME                      STATUS   ROLES           AGE   VERSION
techudaan-control-plane   Ready    control-plane   2m    v1.x.x
techudaan-worker          Ready    <none>          2m    v1.x.x
techudaan-worker2         Ready    <none>          2m    v1.x.x
```

and the context `kind-techudaan`.

### Step 4: Look at the system components

```bash
kubectl get pods -n kube-system -o wide
```

✅ You can see **everything**: `kube-apiserver`, `etcd`, `kube-scheduler`, `kube-controller-manager`, `kube-proxy`, `coredns`, `kindnet`.

> 📌 Remember this list. On cloud clusters (EKS/AKS/GKE), the control-plane Pods are **hidden**, because the provider runs them for you.

---

## 5. Run a Test App

```bash
kubectl create deployment hello --image=nginx --replicas=2
kubectl get pods -o wide
kubectl expose deployment hello --port=80
```

kind has no cloud load balancer, so use **port-forwarding** to reach the app from your laptop:

```bash
kubectl port-forward service/hello 8080:80
```

Open **http://localhost:8080** in your browser (or run `curl localhost:8080` in another terminal). You should see **"Welcome to nginx!"**

Press `Ctrl+C` to stop port-forwarding.

> 💡 Try `kubectl expose deployment hello --port=80 --type=LoadBalancer --name=hello-lb` on kind. The `EXTERNAL-IP` stays `<pending>` forever. There's no cloud to create a load balancer. On EKS/AKS/GKE, this same command gives you a real public IP.

### Optional: Reach apps without port-forwarding

Create a cluster that maps a laptop port to a NodePort:

```yaml
# kind-ports.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 30080
  - role: worker
```

```bash
kind create cluster --name ports --config kind-ports.yaml
kubectl create deployment hello --image=nginx
kubectl create service nodeport hello --tcp=80:80 --node-port=30080
curl http://localhost:30080
kind delete cluster --name ports
kubectl config use-context kind-techudaan
```

---

## 6. Useful kind Commands

| Command | What it does |
|---|---|
| `kind get clusters` | List your clusters |
| `kind get nodes --name techudaan` | List the node containers |
| `kind load docker-image myapp:1.0 --name techudaan` | Use your own locally built image, no registry needed |
| `kind export logs ./logs --name techudaan` | Save all logs for debugging |
| `kind export kubeconfig --name techudaan` | Restore the kubectl context if it got lost |
| `docker exec -it techudaan-worker bash` | Open a shell **inside** a node |

Full list: [cheat sheet](../cheatsheets/kind-cluster-context.md).

---

## 7. Clean Up

```bash
kubectl delete service hello
kubectl delete deployment hello
```

Delete the whole cluster when you're done for the day (recreating it takes about a minute):

```bash
kind delete cluster --name techudaan
```

Check nothing is left:

```bash
kind get clusters
docker ps --filter "label=io.x-k8s.kind.cluster"
```

> 💡 Free disk space occasionally with `docker system prune`. Node images are large.

---

## 8. Troubleshooting

| Problem | Fix |
|---|---|
| `Cannot connect to the Docker daemon` | Start Docker Desktop / Colima / `sudo systemctl start docker` |
| `node(s) already exist for a cluster with the name "techudaan"` | `kind delete cluster --name techudaan`, then create again |
| Creation hangs at `Starting control-plane` | Not enough RAM. Close apps, or use 2 nodes |
| Nodes `NotReady` for over 2 minutes | Wait on first run; else delete and recreate |
| `kubectl` talks to the wrong cluster | `kubectl config use-context kind-techudaan` |
| Cluster broken after laptop restart | `kind delete cluster --name techudaan` and create it again |
| `port is already allocated` (with port mappings) | Another app uses that port; change `hostPort` |

---

## ✅ Recap

- kind runs each Kubernetes **node as a Docker container**: free, fast and safe to break.
- One config file decides the number of nodes; `kind create cluster --config` builds it.
- You can see **every** control-plane component, which you can't on managed cloud clusters.

➡️ Next: [02. AWS EKS](02-aws-eks.md)
