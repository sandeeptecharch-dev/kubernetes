# Module 1: Kubernetes Architecture — Notes

A Kubernetes cluster is a team of machines with **one brain** (the control plane) and **many workers** (the nodes).

By the end of this module you can:

- Name every part of a Kubernetes cluster
- Explain what each part does and what breaks if it stops
- Describe what happens, step by step, when you deploy an app
- Find every component running on your own laptop

**Next:** [lab.md](lab.md) → [break-fix.md](break-fix.md) → [quiz.md](quiz.md)

---

## 1. At a Glance

Every request, from you or from any component, goes through one front door: **the API server**.

```
                    You (kubectl)
                          │
┌─────────────────────────▼──────────────────────────┐
│  CONTROL PLANE (the brain)                         │
│                                                    │
│   etcd  ◄──►  kube-apiserver  ◄──  kube-scheduler  │
│  (database)   (front door)    ◄──  controller-mgr  │
└─────────────────────────▲──────────────────────────┘
                          │  watch and report
          ┌───────────────┴───────────────┐
┌─────────┴──────────┐         ┌──────────┴─────────┐
│  WORKER NODE 1     │         │  WORKER NODE 2     │
│  kubelet           │         │  kubelet           │
│  containerd        │         │  containerd        │
│  kube-proxy        │         │  kube-proxy        │
│  [Pod] [Pod] [Pod] │         │  [Pod] [Pod] [Pod] │
└────────────────────┘         └────────────────────┘
```

Read it top to bottom: you talk to the API server, the API server stores state in etcd, and the scheduler, the controllers and every node's kubelet **watch** the API server and act.

---

## 2. The Railway Analogy

Think of a Kubernetes cluster as **Indian Railways**: a central control room decides what runs where, and stations do the actual work.

| Kubernetes | Indian Railways | Why it fits |
|---|---|---|
| Cluster | The whole railway network | All the machines working together as one system |
| Control plane | Railway Board and control room | Makes decisions; doesn't carry passengers itself |
| kube-apiserver | The reservation counter (the only window) | Every request goes through it; nobody walks into the control room directly |
| etcd | The master reservation chart | The single source of truth: who has which seat, which train runs where |
| kube-scheduler | The officer who assigns trains to platforms | Picks the best node for each new Pod, based on free space and rules |
| Controller manager | Station inspectors on constant rounds | Keep checking "is reality the same as the plan?" and fix it if not |
| Worker node | A railway station with platforms | Where the real work (running containers) happens |
| kubelet | The station master | Takes orders from the control room and makes sure its trains actually run |
| Container runtime | The engine driver | Actually starts and stops the containers |
| kube-proxy | Platform signboards and announcements | Routes traffic to the right Pod, even when Pods move |
| Pod | A train | The unit that runs; it carries one or more containers (coaches) |

---

## 3. Control Plane: The Brain

The control plane decides what should run and keeps checking that it does. It stores the desired state. In a production setup it never runs your app containers itself.

| Component | Its job in one line | If it stops |
|---|---|---|
| **kube-apiserver** | The front door. Every command (`kubectl`, kubelet, controllers) talks to the cluster only through it. It checks who you are and whether you're allowed. | Nobody can read or change anything. Running apps keep running, but you are blind and can't make changes. |
| **etcd** | A key-value database holding the whole cluster state: every Pod, Deployment, Secret and node. Only the API server talks to it. | The cluster loses its memory. Without an etcd backup, a lost etcd means a lost cluster. |
| **kube-scheduler** | Watches for new Pods with no node yet and picks the best node, based on CPU, memory and placement rules. | New Pods stay `Pending` forever. Existing Pods are not affected. |
| **kube-controller-manager** | Runs many control loops (Deployment, ReplicaSet, Node, Job controllers). Each one compares desired state with actual state and fixes the difference. | Self-healing stops: a deleted Pod is not replaced, and a dead node is not noticed. |
| **cloud-controller-manager** | Talks to a cloud provider (AWS, Azure, GCP) to create load balancers, attach disks and manage cloud nodes. | Only on cloud clusters. Cloud load balancers and volumes stop being created. You won't see it on a local kind cluster. |

> ### 💡 The most important idea in Kubernetes
> You tell the cluster the **desired state** ("I want 3 copies of my app"), and controllers work non-stop to make the **actual state** match it.
> This loop of observe, compare and fix is called **reconciliation**.

---

## 4. Worker Nodes: The Muscle

Worker nodes run your actual applications. Every node, worker or control plane, runs these three components.

| Component | Its job in one line | If it stops |
|---|---|---|
| **kubelet** | An agent on every node. It asks the API server "which Pods should run here?", tells the runtime to start them, runs health checks and reports status back. | The node turns `NotReady` within about a minute. After about 5 minutes (the default), its Pods are marked for eviction and replaced on other nodes. |
| **Container runtime** (usually **containerd**) | Pulls images and actually starts and stops containers. Kubernetes talks to it through a standard interface called **CRI**. | No container on that node can start. |
| **kube-proxy** | Sets up network rules on the node so traffic sent to a Service reaches the right Pods. | New or changed Services stop routing correctly on that node. Some network plugins replace kube-proxy entirely. |

### Add-ons almost every cluster needs

- **CoreDNS:** gives Services names, so an app can call `http://payment-service` instead of an IP address.
- **CNI network plugin** (for example Calico, Cilium or Flannel; kind uses **kindnet**): gives every Pod its own IP address and lets Pods on different nodes talk to each other.
- **metrics-server** (optional): collects CPU and memory usage for `kubectl top` and autoscaling.

> **Remember:** the control plane is the brain, the nodes are the muscle, and the API server is the nervous system that connects them. Components never talk to each other directly; they all go through the API server.

---

## 5. What Happens When You Deploy an App

One command passes through every component before a container runs:

```bash
kubectl create deployment web --image=nginx --replicas=3
```

1. **kubectl → API server:** kubectl turns your command into an API request and sends it to the API server.
2. **API server checks you:** who are you (authentication), are you allowed (authorization, RBAC), and is the request valid (admission)?
3. **API server → etcd:** the Deployment object is saved in etcd. Your command returns now, but nothing is running yet.
4. **Deployment controller:** sees a new Deployment and creates a ReplicaSet for it.
5. **ReplicaSet controller:** sees the ReplicaSet wants 3 Pods but 0 exist, so it creates 3 Pod objects. They have no node yet, so their status is `Pending`.
6. **Scheduler:** sees 3 Pods with no node, checks free CPU and memory on every node, and assigns each Pod to a node.
7. **kubelet on each chosen node:** sees a Pod assigned to its node and asks the container runtime to start it.
8. **Container runtime:** pulls the `nginx` image and starts the container. The CNI plugin gives the Pod an IP address.
9. **kubelet reports back:** Pod status becomes `Running`, saved in etcd through the API server.
10. **Self-healing, forever after:** if one Pod dies, the ReplicaSet controller notices 2 ≠ 3 and creates a new one, and the journey repeats from step 6.

Notice that no component gives orders directly to another. Each one **watches** the API server for changes it cares about and acts on them. That's why Kubernetes keeps working even when one part is slow or restarts.

---

**Next:** put this into practice in [lab.md](lab.md).
