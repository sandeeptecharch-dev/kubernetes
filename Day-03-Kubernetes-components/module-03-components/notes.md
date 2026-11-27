# Module 3: Kubernetes Components — Deep Dive

In [Module 1](../module-01-architecture/notes.md) you met the components and learned **where** they sit.
In this module you go one level deeper: **how** each component does its job, and how to **prove it** on your own cluster.

By the end of this module you can:

- Explain how each component works, not just what it is
- Show each component doing its job, with one command per component
- Debug the most common problems caused by each component
- Answer component questions in interviews with confidence

**Next:** [lab.md](lab.md) → [break-fix.md](break-fix.md) → [quiz.md](quiz.md)

---

## The 9 Components at a Glance

| # | Component | Where it runs | How it runs | One-line job |
|---|---|---|---|---|
| 1 | kube-apiserver | Control plane | Static Pod | The only door into the cluster |
| 2 | etcd | Control plane | Static Pod | Stores the whole cluster state |
| 3 | kube-scheduler | Control plane | Static Pod | Picks a node for every new Pod |
| 4 | kube-controller-manager | Control plane | Static Pod | Runs the loops that fix differences |
| 5 | kubelet | Every node | System service (not a Pod) | Runs Pods on its node |
| 6 | Container runtime (containerd) | Every node | System service | Pulls images, starts containers |
| 7 | kube-proxy | Every node | DaemonSet Pod | Makes Services reachable |
| 8 | CoreDNS | Usually 2 Pods | Deployment | Gives Services names |
| 9 | CNI plugin (kindnet on kind) | Every node | DaemonSet Pod | Gives Pods IPs and connects them |

> 💡 **Interview trick:** "How does each component run?" is a favourite question.
> Control-plane parts are **static Pods**, the kubelet and runtime are **system services**, and kube-proxy and CNI are **DaemonSets**.

---

## 1. kube-apiserver: The Front Door

**What it really is:** a REST API server. Every `kubectl` command is just an HTTPS request.

**Every request passes 3 gates:**

```
Request ──► 1. Authentication ──► 2. Authorization ──► 3. Admission ──► saved in etcd
            "Who are you?"        "Are you allowed?"    "Is it valid?
                                  (RBAC)                 Change anything?"
```

**Key facts:**

- It is the **only** component that talks to etcd.
- It is **stateless**: production clusters run 3 copies behind a load balancer.
- Other components don't poll it constantly; they open a **watch** and get notified when something changes.

**Prove it:** `kubectl get pods -v=6` prints the real HTTP request, such as `GET https://127.0.0.1:xxxxx/api/v1/namespaces/default/pods`.

| Common problem | Symptom |
|---|---|
| API server down | `The connection to the server ... was refused` |
| Wrong credentials | `error: You must be logged in to the server (Unauthorized)` |
| Missing permission | `Error from server (Forbidden): pods is forbidden` |

---

## 2. etcd: The Cluster's Memory

**What it really is:** a distributed key-value database. Every object is stored under a key like:

```
/registry/deployments/default/web
/registry/pods/default/web-7d9f8c-abc12
/registry/secrets/default/db-password
```

**Key facts:**

- It uses the **Raft** algorithm, so production runs **3 or 5** members (an odd number) to survive failures and keep a majority.
- **Secrets are only base64-encoded in etcd by default, not encrypted.** Anyone who can read etcd can read every password. Production clusters turn on encryption at rest.
- **Back up etcd.** No etcd backup means no cluster recovery.

**Prove it:** read keys straight from etcd in the lab (Step 2).

| Common problem | Symptom |
|---|---|
| etcd slow (slow disk) | API server responses become slow, timeouts |
| etcd lost with no backup | The whole cluster's state is gone |

---

## 3. kube-scheduler: The Matchmaker

**What it really is:** a loop that finds Pods with an empty `nodeName` and fills it in.

**It decides in 2 phases:**

```
All nodes ──► 1. FILTER ──────────────► 2. SCORE ─────────────► Best node
              Remove nodes that can't     Rank the rest:          (writes nodeName
              run the Pod:                most free resources,     into the Pod)
              • not enough CPU/memory     spread across nodes,
              • nodeSelector mismatch     image already present
              • taints not tolerated
```

**Key facts:**

- The scheduler only **decides**. It never starts containers; the kubelet does that.
- It schedules using **requests** (what a Pod asks for), not actual usage.
- The control-plane node has a **taint**, which is why your app Pods never land there.

**Prove it:** `kubectl describe pod <pending-pod>` shows the filter result, such as `0/3 nodes are available: 3 Insufficient cpu.`

| Common problem | Symptom |
|---|---|
| CPU/memory request too big | `Pending`, event: `Insufficient cpu` / `Insufficient memory` |
| nodeSelector matches no node | `Pending`, event: `didn't match Pod's node affinity/selector` |
| Scheduler down | `Pending`, **no events at all** |

---

## 4. kube-controller-manager: The Fixer

**What it really is:** one process running **dozens of controllers**. Each controller is a loop:

```
        ┌──────────────► OBSERVE actual state
        │                        │
   ACT to fix it  ◄──── COMPARE with desired state
```

**Controllers you'll meet first:**

| Controller | Watches | Does |
|---|---|---|
| Deployment | Deployments | Creates and updates ReplicaSets (rolling updates) |
| ReplicaSet | ReplicaSets | Keeps the right number of Pods |
| Node lifecycle | Node heartbeats | Marks nodes `NotReady`, evicts their Pods |
| Job | Jobs | Runs Pods until the task completes |
| EndpointSlice | Services + Pods | Keeps the list of Pod IPs behind each Service |
| Garbage collector | ownerReferences | Deletes children when a parent is deleted |

**Key facts:**

- Objects form a family tree: **Deployment → ReplicaSet → Pod**. Each child records its parent in `ownerReferences`.
- Delete the Deployment and the garbage collector deletes the ReplicaSet and its Pods.

**Prove it:** `kubectl get pod <name> -o jsonpath='{.metadata.ownerReferences[0].kind}'` prints `ReplicaSet`.

---

## 5. kubelet: The Node Agent

**What it really is:** a system service (not a Pod) on every node. It's the only component that makes things **actually run**.

**Its jobs:**

1. Watches the API server for Pods assigned to its node
2. Asks the container runtime to start them (through **CRI**)
3. Runs **liveness** and **readiness** probes and restarts failed containers
4. Reports Pod and node status back to the API server
5. Sends a **heartbeat** (a Lease object) so the control plane knows the node is alive
6. Runs **static Pods** straight from files in `/etc/kubernetes/manifests`, without any API server

**Key facts:**

- Its config lives in `/var/lib/kubelet/config.yaml`.
- A static Pod shows up in `kubectl` as a read-only **mirror Pod**, named `<pod>-<node-name>`. Deleting it with `kubectl` doesn't work; the kubelet brings it back.

| Common problem | Symptom |
|---|---|
| kubelet stopped | Node `NotReady` |
| Image doesn't exist | `ErrImagePull` / `ImagePullBackOff` |
| App keeps crashing | `CrashLoopBackOff` (the kubelet restarts it with growing delays) |

---

## 6. Container Runtime (containerd): The Engine

**What it really is:** the software that actually pulls images and runs containers. Kubernetes talks to it through the **Container Runtime Interface (CRI)**, so any CRI runtime works (containerd, CRI-O).

**Key facts:**

- Kubernetes stopped talking to Docker directly in v1.24 (dockershim was removed). Images built with Docker still work everywhere, because they follow the same image standard (OCI).
- Every Pod gets a tiny hidden **pause** container that holds the Pod's network namespace. That's how all containers in a Pod share one IP.
- Debug it on a node with **`crictl`**, the CRI equivalent of `docker` commands.

| `docker` habit | On a Kubernetes node |
|---|---|
| `docker ps` | `crictl ps` |
| `docker images` | `crictl images` |
| `docker logs <id>` | `crictl logs <id>` |
| _(no equivalent)_ | `crictl pods` (lists Pod sandboxes) |

---

## 7. kube-proxy: The Traffic Router

**What it really is:** a DaemonSet Pod on every node that turns **Services** into network rules.

**How it works:**

```
App calls Service IP 10.96.45.12:80
        │
        ▼
Rules on the node (written by kube-proxy)
        │   pick one healthy Pod
        ▼
Pod IP 10.244.1.5:80   (or 10.244.2.7, or 10.244.1.9)
```

**Key facts:**

- A Service IP (ClusterIP) is **virtual**: no machine actually has that IP. It exists only in kube-proxy's rules.
- Modes: **iptables** (common default), **IPVS**, and the newer **nftables**. Some CNI plugins, such as Cilium, can replace kube-proxy entirely.
- kube-proxy does **not** carry traffic itself; it only writes the rules. The Linux kernel moves the packets.

| Common problem | Symptom |
|---|---|
| Service selector doesn't match Pod labels | Service has no endpoints; connection refused |
| kube-proxy not running on a node | Services fail only from that node |

---

## 8. CoreDNS: The Phone Book

**What it really is:** a DNS server running as a Deployment (usually 2 Pods) in `kube-system`.

**Key facts:**

- Every Service gets a name: `<service>.<namespace>.svc.cluster.local`
- Inside the same namespace, just `web` works. From another namespace, use `web.default`.
- Every Pod's `/etc/resolv.conf` points to CoreDNS automatically.

| Common problem | Symptom |
|---|---|
| CoreDNS down | Apps fail with `could not resolve host`, but calling by IP still works |
| Wrong namespace in the name | `NXDOMAIN` (name not found) |

---

## 9. CNI Plugin: The Road Network

**What it really is:** the plugin that gives every Pod an IP address and connects Pods across nodes. Kubernetes defines the rules; the CNI plugin implements them.

**The Kubernetes network rules every CNI must follow:**

1. Every Pod gets its own IP address
2. Every Pod can reach every other Pod **without NAT**, even on another node
3. Each node gets its own Pod IP range (`podCIDR`)

**Popular CNI plugins:** Calico, Cilium, Flannel. kind uses **kindnet**.

| Common problem | Symptom |
|---|---|
| No CNI installed | Nodes stay `NotReady`, Pods stuck in `ContainerCreating` |
| Network policy blocking traffic | Pod-to-Pod calls time out |

---

## 🧠 Summary: Which Component Do I Check?

| Symptom | Check first |
|---|---|
| `kubectl` can't connect | kube-apiserver |
| Pod `Pending` with events | Scheduler's reasons: resources, selectors, taints |
| Pod `Pending` with **no** events | kube-scheduler itself |
| Deleted Pod not replaced | kube-controller-manager |
| Node `NotReady` | kubelet, then CNI |
| `ImagePullBackOff` | Image name/tag, registry access (kubelet + runtime) |
| Service unreachable, Pod is fine | Service selector, then kube-proxy |
| "Could not resolve host" | CoreDNS |
| Pods on different nodes can't talk | CNI plugin |

---

**Next:** prove every component on your cluster in [lab.md](lab.md).
