# 06. Container Runtime (containerd): The Engine

> The kubelet gives the orders. The container runtime actually pulls images and starts containers.

⬅️ Previous: [05. kubelet](05-kubelet.md) | ➡️ Next: [07. kube-proxy](07-kube-proxy.md)

---

## 1. What Is It?

A **container runtime** is the software that does the low-level work:

- **Pulls** container images from a registry
- **Creates and starts** containers
- **Stops and deletes** them
- Sets up the **isolation** (Linux namespaces and cgroups)

Kubernetes doesn't care which runtime you use, as long as it speaks the **Container Runtime Interface (CRI)**. The most common one is **containerd**. Another is **CRI-O**.

---

## 2. Real-Life Analogy 🚆

The container runtime is the **engine driver**.

- The **station master** (kubelet) says, "Start train 12951 on platform 2."
- The **engine driver** (containerd) actually fires up the engine and moves the train.
- The station master doesn't need to know how the engine works. They just give standard instructions (CRI).

---

## 3. How It Works

```
   kubelet
      │  CRI (a standard gRPC API)
      ▼
   containerd            ◄── pulls images from Docker Hub, GHCR, ...
      │
      ▼
   runc                  ◄── low-level tool that creates the container
      │                      using Linux namespaces + cgroups
      ▼
 ┌──────────────── one Pod ──────────────────┐
 │  [pause]   [nginx]   [sidecar]            │
 │     ▲                                     │
 │     └─ holds the Pod's network namespace: │
 │        all containers share ONE IP        │
 └───────────────────────────────────────────┘
```

### What about Docker? 🤔

| Question | Answer |
|---|---|
| Does Kubernetes still use Docker? | **No.** Kubernetes stopped talking to Docker directly in **v1.24** (dockershim removed). |
| Do Docker-built images still work? | **Yes.** Docker builds standard **OCI images**, and containerd runs OCI images. |
| Should I still learn Docker? | **Yes,** to build images. Kubernetes just doesn't use it to **run** them. |
| Why does kind need Docker, then? | In kind, each **node** is a Docker container, and **inside** each node, containerd runs your Pods. |

---

## 4. Key Facts to Remember

| Fact | Why it matters |
|---|---|
| Kubernetes talks to runtimes through **CRI** | Any CRI runtime works: containerd, CRI-O |
| Use **`crictl`** on nodes, not `docker` | `crictl` speaks CRI, so it works with any runtime |
| Every Pod has a hidden **pause** container | It holds the Pod's network, so all containers share one IP |
| Containers in one Pod can talk via **localhost** | They share the same network namespace |
| The runtime is a **system service**, like the kubelet | Check it with `systemctl status containerd` |

---

## 5. Practical 🧪

**Setup:**

```bash
kubectl create deployment web --image=nginx --replicas=3 2>/dev/null || true
```

### Step 1: Find the runtime

```bash
kubectl get nodes -o wide
```

**Expected:** a `CONTAINER-RUNTIME` column showing `containerd://1.x.x`.

```bash
docker exec techudaan-worker systemctl status containerd --no-pager | head -5
docker exec techudaan-worker crictl version
```

**What this proves:** containerd runs as a system service on every node, and `crictl` talks to it through CRI.

### Step 2: See how the kubelet connects to it

```bash
docker exec techudaan-worker sh -c 'grep -rh "containerd.sock" /var/lib/kubelet/ 2>/dev/null | head -3'
```

**Expected:** a path like `unix:///run/containerd/containerd.sock`.

**What this proves:** the kubelet and containerd talk through this socket, using the CRI API.

### Step 3: Your new commands (`crictl`)

```bash
docker exec techudaan-worker crictl pods
docker exec techudaan-worker crictl ps
docker exec techudaan-worker crictl images
```

| `docker` habit | On a Kubernetes node |
|---|---|
| `docker ps` | `crictl ps` |
| `docker images` | `crictl images` |
| `docker logs <id>` | `crictl logs <id>` |
| `docker inspect <id>` | `crictl inspect <id>` |
| `docker pull <image>` | `crictl pull <image>` |
| _(no equivalent)_ | `crictl pods` |

**What this proves:** `crictl` is how you debug containers directly on a node, even when `kubectl` isn't available.

### Step 4: Find the hidden pause container

```bash
docker exec techudaan-worker crictl pods | wc -l
docker exec techudaan-worker crictl images | grep pause
```

**Expected:** a `pause` image (a few hundred KB), and one Pod sandbox per Pod on this node.

**What this proves:** each Pod first gets a tiny **pause** container that creates and holds its network. Your real containers then join it.

### Step 5: Two containers, one IP

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: two-in-one
spec:
  containers:
    - name: web
      image: nginx
    - name: helper
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
EOF
kubectl wait --for=condition=Ready pod/two-in-one --timeout=60s
kubectl exec two-in-one -c helper -- wget -qO- localhost | head -4
```

**Expected:** the nginx welcome page, fetched by the **helper** container from **localhost**.

**What this proves:** both containers share one network namespace (held by pause), so `localhost` means the same thing to both. This is how **sidecars** work.

### Step 6: Pull an image like the kubelet does

```bash
docker exec techudaan-worker crictl pull busybox:1.36
docker exec techudaan-worker crictl images | grep busybox
```

**What this proves:** when a Pod is scheduled, the kubelet asks containerd to do exactly this pull before starting the container.

### Step 7: Find a Pod's container and read its logs on the node

```bash
POD=$(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}')
NODE=$(kubectl get pod $POD -o jsonpath='{.spec.nodeName}')
echo "$POD runs on $NODE"
CID=$(docker exec $NODE crictl ps --name nginx -q | head -1)
docker exec $NODE crictl logs $CID | tail -3
```

**What this proves:** `kubectl logs` is just the kubelet fetching these same logs from the runtime for you.

### Clean up

```bash
kubectl delete pod two-in-one
```

---

## 6. Break It and Fix It 💥

> ⚠️ Lab cluster only.

**Break:** deploy an image that doesn't exist.

```bash
kubectl create deployment broken --image=nginx:9.99-does-not-exist
kubectl get pods -l app=broken -w
```

Press `Ctrl+C` after about 30 seconds.

**Observe:** `ErrImagePull` → `ImagePullBackOff`.

```bash
kubectl describe pod -l app=broken | grep -iE "failed|pull" | tail -4
```

The event shows the runtime's real error, such as `not found` or `manifest unknown`.

**Fix:** correct the image, and the Deployment rolls out a fixed Pod:

```bash
kubectl set image deployment/broken nginx=nginx:latest
kubectl get pods -l app=broken -w
```

Press `Ctrl+C` once it's `Running`, then:

```bash
kubectl delete deployment broken
```

**Lesson:** `ImagePullBackOff` means the runtime couldn't get the image. Check, in order: **spelling, tag, registry, login**.

---

## 7. Common Errors

| Status / message | Meaning | Fix |
|---|---|---|
| `ErrImagePull` / `ImagePullBackOff` | Image can't be pulled | Fix the name/tag; for private registries add `imagePullSecrets` |
| `manifest unknown` / `not found` | That tag doesn't exist | Check the tag on the registry |
| `unauthorized` / `pull access denied` | Private image without credentials | Create a registry Secret and reference it |
| `toomanyrequests` | Registry rate limit (e.g. Docker Hub) | Log in, or use a mirror |
| `ContainerCreating` for a long time | Big image pulling, or volume/network setup stuck | `kubectl describe pod` → Events |

---

## 8. Interview Questions 🎤

1. What is CRI, and why does Kubernetes use it?
2. Kubernetes removed dockershim. Do Docker images still work?
3. What is the pause container?
4. How do two containers in the same Pod talk to each other?
5. How would you list containers on a node if `kubectl` wasn't working?

<details>
<summary>Answers</summary>

1. The Container Runtime Interface: a standard API between the kubelet and the runtime, so Kubernetes works with any compliant runtime.
2. Yes. Docker builds standard OCI images, which containerd and CRI-O run.
3. A tiny container started first in every Pod. It holds the Pod's network namespace, which the other containers join.
4. Through `localhost`, because they share one network namespace.
5. On the node: `crictl ps` (and `crictl pods`, `crictl logs`).

</details>

---

## ✅ Recap

- The runtime (**containerd**) pulls images and runs containers; the kubelet talks to it via **CRI**.
- On nodes, use **`crictl`**, not `docker`. Docker-built images still work everywhere.
- Every Pod has a hidden **pause** container, so all its containers share one IP.

➡️ Next: [07. kube-proxy, the traffic router](07-kube-proxy.md)
