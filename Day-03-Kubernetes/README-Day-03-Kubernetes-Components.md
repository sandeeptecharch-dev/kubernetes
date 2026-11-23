# Day 03: Kubernetes Components – How Kubernetes Works Behind the Scenes

> **30 Days of Kubernetes Learning Challenge**  
> Learn Kubernetes components through a real-world e-commerce production scenario.

## 1. What Are Kubernetes Components?

Kubernetes is made up of multiple components that work together to deploy, manage, monitor, and maintain containerized applications.

To understand them, imagine that we operate an e-commerce application similar to Amazon.

Our application has multiple microservices:

- **User Service** – Login and registration
- **Product Service** – Product catalogue
- **Order Service** – Order creation
- **Payment Service** – Payment processing
- **Notification Service** – Email and SMS notifications

During a festival sale, thousands of customers may access the application simultaneously. We need Kubernetes to schedule workloads, recover from failures, and maintain the desired application state.

## 2. Kubernetes Architecture

Kubernetes architecture has two major parts:

1. **Control Plane** – Makes cluster-level decisions and manages the desired state.
2. **Worker Nodes** – Run application Pods.

### Control Plane components

- API Server
- etcd
- Scheduler
- Controller Manager

### Worker Node components

- Kubelet
- Container Runtime
- kube-proxy (commonly used for Service networking)

## 3. Understand Each Component with a Story

### 3.1 API Server – The Receptionist

The API Server is the front door of Kubernetes. It exposes the Kubernetes API and handles requests from `kubectl`, automation tools, and other components.

For example, when we run:

```bash
kubectl apply -f order-deployment.yaml
```

The request reaches the API Server. It authenticates and authorizes the request, validates it, and processes the API operation.

**Main responsibilities:**

- Exposes the Kubernetes API.
- Authenticates and authorizes requests.
- Validates API objects.
- Provides the communication point for control-plane and cluster components.

**Production failure scenario:** If the API Server is unavailable, new Kubernetes API operations and normal cluster management are impaired. Existing containers can generally continue running, but components cannot reliably report or reconcile changes through the API.

**Remember:** API Server = Receptionist / Entry point.

### 3.2 etcd – The Cluster Database

Imagine a company database that stores important records. etcd plays a similar role for Kubernetes.

etcd is a distributed key-value store that holds Kubernetes cluster data, such as configuration, metadata, and the persisted state of API objects.

**Main responsibilities:**

- Stores Kubernetes cluster state.
- Persists configuration and metadata.
- Supports reliable state storage through distributed consensus.

**Production failure scenario:** If etcd loses quorum, Kubernetes cannot reliably persist new state changes. Existing workloads may continue running, but cluster management becomes impaired.

**Important:** etcd uses the Raft consensus algorithm. A three-member etcd cluster needs at least two healthy members to maintain quorum.

**Remember:** etcd = Cluster database / Memory.

### 3.3 Scheduler – The Resource Manager

Imagine an e-commerce company with three offices. A manager must decide which office has enough capacity to handle new work.

The Kubernetes Scheduler selects a suitable worker node for each newly created Pod that has not yet been assigned to a node.

It considers factors such as:

- Available CPU and memory.
- Resource requests and scheduling constraints.
- Node selectors and affinity/anti-affinity.
- Taints and tolerations.
- Other scheduling policies.

**Production example:** We need three Order Service Pods. The Scheduler selects suitable nodes for those Pods based on cluster resources and scheduling rules.

**Production failure scenario:** Existing Pods continue running, but newly created Pods that need scheduling generally remain Pending until the Scheduler is available again.

**Remember:** Scheduler = Decides where a Pod should run.

### 3.4 Controller Manager – The Supervisor

Imagine the business owner says:

"Our Order Service must always have three replicas."

If one Pod fails, the number of running replicas may fall to two. Kubernetes controllers continuously work to bring the actual state back toward the desired state.

For a Deployment:

- The Deployment Controller manages the ReplicaSet.
- The ReplicaSet Controller ensures the required number of Pods.

**Main responsibility:** Reconcile actual state with desired state.

**Production failure scenario:** If the relevant controllers are unavailable, existing Pods generally continue running, but automated reconciliation and recovery actions may be delayed or interrupted.

**Remember:** Controller Manager = Supervisor that keeps checking the desired state.

### 3.5 Kubelet – The Worker Node Manager

Kubelet is an agent that runs on every worker node.

When a Pod is assigned to a node, the Kubelet on that node works to ensure the Pod's containers are running according to the Pod specification.

**Main responsibilities:**

- Communicates with the Kubernetes API.
- Receives and processes assigned Pod specifications.
- Works with the container runtime.
- Reports node and Pod status.

**Production failure scenario:** If Kubelet stops, existing containers may continue running, but Kubernetes loses normal health reporting from that node. The node may eventually be marked NotReady.

**Remember:** Kubelet = Node-level agent responsible for assigned Pods.

### 3.6 Container Runtime – The Execution Engine

Kubelet needs a container runtime to actually run containers.

Examples:

- containerd
- CRI-O

The runtime pulls container images when required and creates and runs containers.

**Remember:** Kubelet manages the Pod lifecycle; the container runtime executes containers.

### 3.7 kube-proxy – The Network Assistant

kube-proxy runs on nodes in many Kubernetes clusters and helps implement Kubernetes Service networking by maintaining network rules.

It helps route traffic to the appropriate backend Pods. Some cluster networking implementations replace kube-proxy with another solution.

**Remember:** kube-proxy = Helps implement Service networking.

## 4. Production Deployment Example

Let's deploy an Order Service with three replicas.

Create a file named `order-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
        - name: order
          image: nginx:latest
          ports:
            - containerPort: 80
```

> For this learning example, `nginx:latest` is used as a sample container image. Replace it with your actual Order Service image for a real application.

Apply the deployment:

```bash
kubectl apply -f order-deployment.yaml
```

Check the deployment:

```bash
kubectl get deployments
```

Check the Pods:

```bash
kubectl get pods -o wide
```

Check the ReplicaSets:

```bash
kubectl get rs
```

## 5. How Components Work Together

When we apply the Deployment YAML, the high-level flow is:

1. **API Server:** Receives and validates the Deployment request.
2. **etcd:** The API Server persists the accepted API state in etcd.
3. **Controller Manager:** The Deployment and ReplicaSet controllers work to create the required three Pods.
4. **Scheduler:** Selects a suitable worker node for each unscheduled Pod.
5. **Kubelet:** On each selected node, works to ensure the assigned Pod is running.
6. **Container Runtime:** Pulls the image when needed and starts the container.
7. **Status reporting:** Kubelet and other components report information through the API Server.

These components do not simply run once in a fixed sequence. They continuously communicate and reconcile cluster state.

## 6. Production Failure Scenario – What If an Order Pod Crashes?

Suppose the desired replica count is three:

```yaml
replicas: 3
```

One Order Service Pod crashes.

The ReplicaSet Controller observes that the actual number of Pods is below the desired count and creates a replacement Pod.

The Scheduler assigns the new Pod to a suitable node. The Kubelet on that node works with the container runtime to start its container.

Kubernetes works toward restoring the desired replica count.

This behavior is part of Kubernetes **self-healing**.

> Kubernetes can recreate failed Pods, but it cannot automatically fix a bug in your application code.

## 7. Useful Kubernetes Commands

| Purpose | Command |
|---|---|
| Check cluster nodes | `kubectl get nodes` |
| Check all Pods | `kubectl get pods -A` |
| Check Deployments | `kubectl get deployments -A` |
| Check ReplicaSets | `kubectl get rs -A` |
| Check system Pods | `kubectl get pods -n kube-system` |
| Describe a Pod | `kubectl describe pod <pod-name>` |
| Describe a node | `kubectl describe node <node-name>` |
| View cluster information | `kubectl cluster-info` |
| View Pod logs | `kubectl logs <pod-name>` |

**Note:** Kubelet and the container runtime are node-level processes, not ordinary Pods. They will not appear as Pods in the `kube-system` namespace.

## 8. Quick Revision

| Component | Simple analogy | Main responsibility |
|---|---|---|
| API Server | Receptionist | Handles Kubernetes API requests |
| etcd | Database | Stores cluster state |
| Scheduler | Resource manager | Selects worker nodes for Pods |
| Controller Manager | Supervisor | Reconciles desired and actual state |
| Kubelet | Node manager | Ensures assigned Pods are running |
| Container Runtime | Execution engine | Runs containers |
| kube-proxy | Network assistant | Helps implement Service networking |

## 9. Interview Questions

1. What is the role of the Kubernetes API Server?
2. Why does Kubernetes use etcd?
3. What is quorum in etcd?
4. What happens if the Scheduler goes down?
5. What is the difference between Scheduler and Controller Manager?
6. What is the role of Kubelet?
7. What is the difference between Kubelet and Container Runtime?
8. What happens when a Pod crashes in a Deployment?
9. Can existing application containers continue running if the API Server goes down?
10. How does Kubernetes maintain the desired replica count?

## 10. Hands-on Practice

Complete these exercises in your local Kind or other Kubernetes cluster:

- [ ] Check all worker nodes.
- [ ] Check the Pods in `kube-system`.
- [ ] Deploy the sample Order Service Deployment.
- [ ] Verify that three replicas are running.
- [ ] Delete one Order Service Pod.
- [ ] Watch Kubernetes create a replacement Pod.
- [ ] Inspect the Deployment, ReplicaSet, and Pod descriptions.
- [ ] Review the events using `kubectl get events --sort-by=.metadata.creationTimestamp`.

## Key Takeaway

Kubernetes is not a single application that performs all tasks. It is a collection of components that work together.

- API Server receives requests.
- etcd stores cluster state.
- Scheduler selects nodes.
- Controllers reconcile the desired state.
- Kubelet manages assigned Pods on worker nodes.
- Container Runtime runs containers.

Understanding how these components interact is essential for troubleshooting real production Kubernetes clusters.

---

**Next: Day 04 – Kubernetes Pods: The Smallest Deployable Unit**

#Kubernetes #DevOps #KubernetesArchitecture #Docker #CloudNative #LearningInPublic
