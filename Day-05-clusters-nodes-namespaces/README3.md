# Day 4: kind and kubectl, Hands-On 🛠️

> Build real Kubernetes clusters on your laptop, learn the `kubectl` commands you'll use every day, deploy an app, open it in your browser, and run **your own** Docker image on Kubernetes.

⏱️ **Time:** about 90 minutes · 💰 **Cost:** free · 🎯 **Level:** beginner

🏠 [Course home](../README.md) · 🛠️ [Install guide (Module 0)](../module-00-setup/README.md) · 📋 [Cheat sheet](../cheatsheets/kind-cluster-context.md)

---

## What You'll Do Today

| Lab | You will… | Time |
|---|---|---|
| [0](#lab-0-check-your-tools) | Check your tools are ready | 5 min |
| [1](#lab-1-your-first-cluster-1-node) | Build your first cluster (1 node) and see what's inside | 10 min |
| [2](#lab-2-the-course-cluster-3-nodes) | Build the 3-node course cluster and verify it | 10 min |
| [3](#lab-3-kubectl-essentials) | Learn the essential `kubectl` commands | 15 min |
| [4](#lab-4-contexts-which-cluster-am-i-talking-to) | Understand contexts: which cluster am I talking to? | 10 min |
| [5](#lab-5-imperative-vs-declarative) | Deploy an app two ways: commands vs YAML | 15 min |
| [6](#lab-6-reach-and-debug-your-app) | Reach your app; read its logs; go inside it | 10 min |
| [7](#lab-7-open-your-app-in-the-browser-port-mapping) | Open your app in the browser with port mapping | 10 min |
| [8](#lab-8-run-your-own-image) | Build your own image and run it on kind | 15 min |
| [9](#lab-9-clean-up) | Clean up | 2 min |

---

## Files in This Folder

```
module-04-kind-kubectl/
├── README.md                    ← you are here
├── kind-configs/
│   ├── kind-1node.yaml          ← smallest cluster (Lab 1)
│   ├── kind-3node.yaml          ← the course cluster (Lab 2)
│   ├── kind-ports.yaml          ← reach apps on localhost:30080 (Lab 7)
│   └── kind-ha.yaml             ← 3 control planes (challenge)
├── manifests/
│   ├── hello-deployment.yaml    ← 2 nginx Pods (Lab 5)
│   └── hello-service.yaml       ← NodePort Service on 30080 (Lab 5, 7)
├── my-app/
│   ├── Dockerfile               ← your own image (Lab 8)
│   ├── index.html               ← the web page inside it
│   └── my-app.yaml              ← Deployment + Service for your image
└── scripts/
    └── verify-cluster.sh        ← checks your cluster is healthy (Lab 2)
```

> 💡 **Run every command from this folder:**
> ```bash
> cd techudaan-kubernetes/module-04-kind-kubectl
> ```

---

## Lab 0: Check Your Tools

You need **Docker**, **kubectl** and **kind**. Not installed yet? Follow [Module 0](../module-00-setup/README.md) first.

```bash
bash ../module-00-setup/check-setup.sh
```

✅ **Expected:** `[OK]` for Docker, kubectl, kind and Git.

---

## Lab 1: Your First Cluster (1 Node)

### What is kind?

**kind** = **K**ubernetes **IN** **D**ocker. Each Kubernetes **node** runs as a **Docker container** on your laptop.

```
Your laptop
└── Docker
    └── container "solo-control-plane"  ← a full Kubernetes node
          └── inside: API server, etcd, scheduler, controller-manager,
                      kubelet, containerd, kube-proxy, CoreDNS, CNI
```

### Step 1: Create it

```bash
kind create cluster --name solo --config kind-configs/kind-1node.yaml
```

The first run downloads the node image (around 1 GB), so it can take a few minutes. Watch the output: each line is one stage of building a cluster.

### Step 2: Look at it from Docker's side

```bash
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
```

✅ One container: `solo-control-plane`, image `kindest/node:...`.

### Step 3: Look at it from Kubernetes' side

```bash
kubectl get nodes
kubectl get pods -n kube-system
```

✅ One node, `Ready`. And all 9 components from Day 3 running inside it.

### Step 4: Go inside the node

```bash
docker exec -it solo-control-plane bash
```

Inside the node, try:

```bash
crictl ps              # containers running on this node
ls /etc/kubernetes/manifests    # the control plane's static Pods
exit
```

### Step 5: Delete it

```bash
kind delete cluster --name solo
docker ps
```

✅ The container is gone. Building and throwing away clusters is **normal** with kind.

---

## Lab 2: The Course Cluster (3 Nodes)

### Step 1: Read the config

```bash
cat kind-configs/kind-3node.yaml
```

| Line | Meaning |
|---|---|
| `kind: Cluster` | This file describes a whole cluster |
| `apiVersion: kind.x-k8s.io/v1alpha4` | Version of kind's config format |
| `- role: control-plane` | 1 node runs the brain |
| `- role: worker` (×2) | 2 nodes run your apps |

### Step 2: Create it

```bash
kind create cluster --name techudaan --config kind-configs/kind-3node.yaml
```

### Step 3: Verify with the script

```bash
bash scripts/verify-cluster.sh techudaan
```

✅ **Expected:** every line `[OK]`, ending with `Cluster 'techudaan' is healthy`.

```
NAME                      STATUS   ROLES           AGE   VERSION
techudaan-control-plane   Ready    control-plane   2m    v1.x.x
techudaan-worker          Ready    <none>          2m    v1.x.x
techudaan-worker2         Ready    <none>          2m    v1.x.x
```

> 💡 **Keep this cluster running** for the rest of today's labs.

---

## Lab 3: kubectl Essentials

`kubectl` is the one tool you use with **every** Kubernetes cluster: kind, EKS, AKS, GKE. The pattern is always:

```
kubectl  <verb>   <resource>   [name]   [flags]
kubectl   get      pods         web     -o wide
```

### 3a. Ask about the cluster

```bash
kubectl version                     # client + server versions
kubectl cluster-info                # where is the API server?
kubectl get nodes -o wide           # nodes with IPs, OS, runtime
kubectl describe node techudaan-worker   # everything about one node
```

### 3b. See what's running

```bash
kubectl get pods                    # Pods in the "default" namespace
kubectl get pods -A                 # Pods in ALL namespaces
kubectl get namespaces              # list namespaces
kubectl get all -n kube-system      # common resources in one namespace
```

### 3c. Change the output format

```bash
kubectl get nodes -o wide           # more columns
kubectl get node techudaan-worker -o yaml    # the full object as YAML
kubectl get nodes -o name           # just the names
kubectl get nodes -o jsonpath='{.items[*].metadata.name}{"\n"}'   # pick exact fields
```

### 3d. Built-in help (no Google needed)

```bash
kubectl api-resources               # every resource type + short names (po, svc, deploy…)
kubectl explain pod.spec.containers # documentation for any field
kubectl get --help                  # help for any command
```

✍️ **Try:** use `kubectl api-resources` to find the short name for `deployments`, then run `kubectl get <short-name> -A`.

---

## Lab 4: Contexts: Which Cluster Am I Talking To?

A **context** = which **cluster** + which **user** + which default **namespace**. kind names it `kind-<cluster-name>`.

```bash
kubectl config current-context      # → kind-techudaan
kubectl config get-contexts         # all contexts; * = current
kubectl config view --minify        # details of the current context
```

### Set a default namespace

```bash
kubectl create namespace practice
kubectl config set-context --current --namespace=practice
kubectl get pods                    # now looks in "practice"
kubectl config set-context --current --namespace=default   # switch back
```

> ⚠️ **Golden habit:** before changing anything, run `kubectl config current-context`. In real jobs, the wrong context can mean deleting production.

More: [kind, cluster and context cheat sheet](../cheatsheets/kind-cluster-context.md).

---

## Lab 5: Imperative vs Declarative

There are two ways to tell Kubernetes what to do.

| | **Imperative** (commands) | **Declarative** (YAML files) |
|---|---|---|
| How | `kubectl create …`, `kubectl scale …` | `kubectl apply -f file.yaml` |
| Good for | Quick tests, learning | **Real work**: files go in Git, are reviewed, repeatable |
| Says | "Do this now" | "This is how it should be" |

### 5a. Imperative

```bash
kubectl create deployment quick --image=nginx --replicas=2
kubectl get deployment quick
kubectl scale deployment quick --replicas=4
kubectl get pods -l app=quick
kubectl delete deployment quick
```

### 5b. Declarative

Read the files first:

```bash
cat manifests/hello-deployment.yaml
cat manifests/hello-service.yaml
```

Apply the whole folder:

```bash
kubectl apply -f manifests/
kubectl get deployment,service,pods -l app=hello
kubectl get svc hello
```

Now change the desired state **in the file**: open `manifests/hello-deployment.yaml`, change `replicas: 2` to `replicas: 3`, save, then:

```bash
kubectl diff -f manifests/hello-deployment.yaml    # preview the change
kubectl apply -f manifests/hello-deployment.yaml
kubectl get pods -l app=hello
```

✅ 3 Pods. You changed a file, and Kubernetes made it true (that's the controller-manager from Day 3).

### 5c. The shortcut pros use: let kubectl write the YAML

```bash
kubectl create deployment demo --image=nginx --replicas=2 --dry-run=client -o yaml
```

Nothing is created; kubectl just prints the YAML. Save it as a starting point:

```bash
kubectl create deployment demo --image=nginx --dry-run=client -o yaml > /tmp/demo.yaml
cat /tmp/demo.yaml
```

> Change `replicas` back to `2` in `manifests/hello-deployment.yaml` when you're done.

---

## Lab 6: Reach and Debug Your App

### 6a. Port-forward: a tunnel from your laptop to the Service

```bash
kubectl port-forward service/hello 8080:80
```

Open **http://localhost:8080**. You should see "Welcome to nginx!". Press `Ctrl+C` to stop.

### 6b. The 4 debugging commands you'll use most

```bash
POD=$(kubectl get pods -l app=hello -o jsonpath='{.items[0].metadata.name}')

kubectl describe pod $POD              # details + Events (read these first!)
kubectl logs $POD                      # what the app printed
kubectl logs $POD -f                   # follow live (Ctrl+C to stop)
kubectl exec -it $POD -- sh            # open a shell INSIDE the container
```

Inside the container, try:

```bash
hostname                    # the Pod's name
cat /usr/share/nginx/html/index.html | head -5
exit
```

| Command | Use it when… |
|---|---|
| `describe` | A Pod is `Pending`, `CrashLoopBackOff`, `ImagePullBackOff`: read **Events** |
| `logs` | The app is running but misbehaving |
| `logs --previous` | The container crashed and restarted; see the **last** run's logs |
| `exec` | You need to look around inside the container |

---

## Lab 7: Open Your App in the Browser (Port Mapping)

Port-forwarding works, but it stops when you close the terminal. With **port mapping**, kind connects a laptop port straight to a NodePort.

```bash
cat kind-configs/kind-ports.yaml
kind create cluster --name web --config kind-configs/kind-ports.yaml
kubectl apply -f manifests/
kubectl get pods -l app=hello -w
```

When both Pods are `Running`, press `Ctrl+C`, then open **http://localhost:30080** in your browser. 🎉

```
Browser → localhost:30080 → kind node container :30080 → NodePort Service "hello" → nginx Pod
```

Switch back to the course cluster and delete this one:

```bash
kind delete cluster --name web
kubectl config use-context kind-techudaan
```

---

## Lab 8: Run Your Own Image

Real apps use **your** images, not just nginx. With kind, you don't even need Docker Hub.

### Step 1: Build the image

```bash
cat my-app/Dockerfile
docker build -t techudaan-hello:1.0 my-app/
docker images | grep techudaan-hello
```

### Step 2: Copy it into the cluster's nodes

Your image is on your laptop's Docker, but the nodes have their **own** containerd. Load it in:

```bash
kind load docker-image techudaan-hello:1.0 --name techudaan
docker exec techudaan-worker crictl images | grep techudaan-hello
```

✅ The image now exists **inside** the worker node.

### Step 3: Run it

```bash
kubectl apply -f my-app/my-app.yaml
kubectl get pods -l app=my-app
kubectl port-forward service/my-app 8081:80
```

Open **http://localhost:8081**. That's **your** page, running on **your** cluster. 🚀 Press `Ctrl+C`.

### Step 4: Release version 2.0

1. Edit `my-app/index.html`: change `Version 1.0` to `Version 2.0`.
2. Build, load and roll out:

```bash
docker build -t techudaan-hello:2.0 my-app/
kind load docker-image techudaan-hello:2.0 --name techudaan
kubectl set image deployment/my-app web=techudaan-hello:2.0
kubectl rollout status deployment/my-app
kubectl port-forward service/my-app 8081:80
```

Refresh **http://localhost:8081**: version 2.0, with zero downtime.

### ⚠️ The `latest` trap (try it!)

```bash
docker tag techudaan-hello:1.0 techudaan-hello:latest
kind load docker-image techudaan-hello:latest --name techudaan
kubectl create deployment trap --image=techudaan-hello:latest
kubectl get pods -l app=trap -w
```

You'll see `ErrImagePull` / `ImagePullBackOff`. **Why?** With the `:latest` tag, Kubernetes defaults to `imagePullPolicy: Always` and tries to download from Docker Hub, where your image doesn't exist.

**Fix:** use a version tag (like `1.0`) with `imagePullPolicy: IfNotPresent`, as in `my-app/my-app.yaml`.

```bash
kubectl delete deployment trap
```

---

## Lab 9: Clean Up

```bash
kubectl delete -f manifests/
kubectl delete -f my-app/my-app.yaml
kubectl delete namespace practice
```

Keep the `techudaan` cluster for the next module, or delete it (recreating takes about a minute):

```bash
kind delete cluster --name techudaan
kind get clusters
```

---

## 🏆 Challenges (Optional)

1. **High availability:** create `kind-configs/kind-ha.yaml` (16 GB RAM recommended). Run `kubectl get nodes` and `docker ps`. How many control planes? What is the extra `external-load-balancer` container for?
2. **Two clusters:** create `dev` and `prod` clusters. Deploy `hello` to `dev` only. Prove `prod` has nothing **without** switching context. (Hint: `--context`)
3. **Generate, don't type:** use `--dry-run=client -o yaml` to create a Service YAML for `my-app` of type `NodePort` on port `30081`.

---

## 🧯 Troubleshooting

| Problem | Fix |
|---|---|
| `Cannot connect to the Docker daemon` | Start Docker Desktop / Colima / `sudo systemctl start docker` |
| `node(s) already exist for a cluster with the name ...` | `kind delete cluster --name <name>` first, or pick another name |
| `port is already allocated` (Lab 7) | Another cluster or app uses port 30080. Delete it, or change `hostPort` |
| `kubectl` talks to the wrong cluster | `kubectl config use-context kind-techudaan` |
| `ErrImagePull` with your own image | Did you `kind load` it into **this** cluster? Avoid `:latest` |
| Pods stuck `Pending` on an 8 GB laptop | Use a 2-node cluster; close other apps |
| `error: unable to forward port` | The Pod isn't `Running` yet; check `kubectl get pods` |

---

## 🧩 Self-Check Quiz

1. You create a cluster with `kind create cluster --name techudaan`. What is the kubectl context name?
2. In kind, what is a "node" physically?
3. What's the difference between `kubectl create` and `kubectl apply -f`?
4. Which flag makes kubectl print YAML without creating anything?
5. Why does a locally loaded image tagged `:latest` fail with `ImagePullBackOff`?
6. Your Pod is `CrashLoopBackOff`. Which command shows the logs from **before** it crashed?

<details>
<summary>Answers</summary>

1. `kind-techudaan`
2. A Docker container running all the node components inside it.
3. `create` is imperative ("make this now", fails if it exists); `apply -f` is declarative ("make it look like this file", creates or updates).
4. `--dry-run=client -o yaml`
5. With `:latest`, the default `imagePullPolicy` is `Always`, so the kubelet tries Docker Hub instead of using the local copy.
6. `kubectl logs <pod> --previous`

</details>

---

➡️ **Next:** [Day 5: Clusters, Nodes and Namespaces](../module-05-clusters-nodes-namespaces/README.md)
