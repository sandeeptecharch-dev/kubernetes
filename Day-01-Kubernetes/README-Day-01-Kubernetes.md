# Day 01: What Is Kubernetes? Why Do We Need It? Architecture and Use Cases

## 1. What Is Kubernetes?

Kubernetes (also called **K8s**) is an open-source container orchestration platform. It helps us deploy, manage, scale, and maintain containerized applications.

Imagine that we have an e-commerce application running in Docker containers. As traffic increases, we may need more application instances. If a container crashes, we need another one to take its place. If we deploy a new version, we want to release it without causing downtime.

Kubernetes helps automate these operational tasks.

**In simple words:** Docker helps package and run containers; Kubernetes helps manage containers across a cluster of machines.

## 2. Why Do We Need Kubernetes?

Let's understand this with an e-commerce example.

Imagine an online shopping platform with these services:

- **User Service** – registration and login
- **Product Service** – product catalogue
- **Order Service** – order creation and tracking
- **Payment Service** – payment processing
- **Notification Service** – email and SMS notifications
- **MongoDB** – application data

Initially, we run each service in a Docker container on one server. This may work when traffic is low. But as the business grows, operational challenges appear.

### Problems without container orchestration

1. **Container failure:** If the Order Service container crashes, someone may need to restart it manually.
2. **Traffic increase:** During a sale, thousands of customers may access the platform. We need more service instances.
3. **Load distribution:** Requests must be distributed across healthy instances.
4. **Deployment risk:** Releasing a new version can cause downtime if the old version is stopped before the new one is ready.
5. **Resource management:** We need to manage CPU and memory across multiple servers.
6. **Service communication:** Services need a reliable way to discover and communicate with one another.

### How Kubernetes helps

| Challenge | Kubernetes capability |
|---|---|
| Container crashes | Restarts containers and helps maintain the desired number of replicas |
| More customer traffic | Scales application replicas manually or through autoscaling |
| Unhealthy instances | Uses health probes and replaces unhealthy Pods |
| Deployment downtime | Supports rolling updates and rollbacks |
| Service communication | Provides Services and DNS-based service discovery |
| Workload placement | Schedules Pods on suitable worker nodes |
| Configuration and secrets | Manages ConfigMaps and Secrets |

Kubernetes continuously compares the actual state of the cluster with the desired state we define. It works to bring the actual state back to the desired state.

## 3. Kubernetes Architecture

A Kubernetes cluster is made up of a **Control Plane** and **Worker Nodes**.

### A. Control Plane

The Control Plane manages the cluster. It makes decisions about scheduling, observes the cluster, and helps maintain the desired state.

| Component | Responsibility |
|---|---|
| **kube-apiserver** | Entry point for Kubernetes API requests. `kubectl` communicates with the cluster through the API server. |
| **etcd** | Distributed key-value store that holds Kubernetes cluster state and configuration. |
| **kube-scheduler** | Selects an appropriate worker node for newly created Pods. |
| **kube-controller-manager** | Runs controllers that monitor the cluster and work to maintain the desired state. |
| **cloud-controller-manager** | Integrates Kubernetes with a cloud provider when required. |

### B. Worker Nodes

Worker nodes run our application workloads.

| Component | Responsibility |
|---|---|
| **kubelet** | Agent on each node that ensures the containers described by assigned Pods are running. |
| **kube-proxy** | Implements Service networking rules on nodes, depending on the cluster network implementation. |
| **Container Runtime** | Runs containers, for example containerd or CRI-O. |
| **Pods** | Smallest deployable units in Kubernetes. A Pod contains one or more closely related containers. |

### Architecture at a glance

```text
                    Kubernetes Cluster
                           |
             +-------------+-------------+
             |       Control Plane       |
             |                           |
             |  kube-apiserver           |
             |  etcd                     |
             |  kube-scheduler           |
             |  controller-manager       |
             +-------------+-------------+
                           |
                  Schedules and manages
                           |
             +-------------+-------------+
             |                           |
       Worker Node 1                Worker Node 2
       +----------------+           +----------------+
       | kubelet        |           | kubelet        |
       | kube-proxy     |           | kube-proxy     |
       |                |           |                |
       | Pod            |           | Pod            |
       |  User Service  |           |  Order Service |
       |                |           |                |
       | Pod            |           | Pod            |
       | Product Service|           | Payment Service|
       +----------------+           +----------------+
```

> Note: This is a simplified conceptual diagram. A production cluster may have multiple Control Plane nodes, additional networking components, and managed cloud integrations.

## 4. Important Kubernetes Objects

- **Cluster:** A set of Control Plane and Worker Node components managed as one Kubernetes environment.
- **Node:** A machine (virtual or physical) that runs Pods.
- **Pod:** The smallest deployable unit; it runs one or more containers.
- **Deployment:** Manages stateless application Pods and supports scaling and rolling updates.
- **Service:** Provides a stable network endpoint for accessing a set of Pods.
- **ConfigMap:** Stores non-sensitive configuration.
- **Secret:** Stores sensitive configuration data. Apply appropriate encryption and access controls.
- **Namespace:** Helps organize and isolate resources within a cluster.

## 5. E-commerce Example: What Happens When Traffic Increases?

Suppose our Order Service normally runs with two replicas.

1. We create a Deployment that declares two Order Service replicas.
2. Kubernetes schedules the Pods onto available Worker Nodes.
3. A Service provides a stable endpoint to reach the Order Service Pods.
4. During a sale, traffic increases. We can scale the Deployment to five replicas, or configure a Horizontal Pod Autoscaler.
5. Kubernetes schedules additional Pods, subject to available cluster resources.
6. If a Pod becomes unhealthy, health probes can detect the problem and Kubernetes works to replace it.
7. During a release, a rolling update can gradually replace old Pods with new ones.

Example commands:

```bash
# Check cluster nodes
kubectl get nodes

# Check Pods in the current namespace
kubectl get pods

# Create a Deployment with two replicas
kubectl create deployment order-service --image=nginx --replicas=2

# Check the Deployment
kubectl get deployments

# Scale it to five replicas
kubectl scale deployment order-service --replicas=5

# Check Pods again
kubectl get pods

# Delete the practice Deployment
kubectl delete deployment order-service
```

The `nginx` image above is only used for this basic practice exercise. It is not an actual Order Service application.

## 6. Where Is Kubernetes Used?

Kubernetes is commonly used for:

- **Microservices:** Running and managing independently deployable services.
- **E-commerce:** Scaling product, cart, order, and payment workloads.
- **Banking and fintech:** Operating containerized application platforms with appropriate security and compliance controls.
- **Media and streaming:** Handling changing workloads and traffic demand.
- **SaaS platforms:** Deploying and scaling services for customers.
- **CI/CD platforms:** Supporting automated application deployment workflows.
- **Hybrid and multi-cloud environments:** Providing a consistent orchestration layer across supported infrastructure.

Kubernetes is powerful, but it is not required for every application. A small application with simple hosting needs may be easier and cheaper to operate without it.

## 7. Key Takeaways

- Kubernetes is a container orchestration platform.
- It automates deployment, scaling, scheduling, and recovery of containerized workloads.
- The Control Plane manages the cluster; Worker Nodes run application Pods.
- Pods are the smallest deployable units in Kubernetes.
- Deployments manage application replicas and rolling updates.
- Services provide stable networking for accessing Pods.
- Kubernetes helps manage complex applications at scale, but it also introduces operational complexity.

## 8. Interview Questions

1. What is Kubernetes, and why do we use it?
2. What is the difference between Docker and Kubernetes?
3. What are the main components of the Kubernetes Control Plane?
4. What is etcd, and what information does it store?
5. What is the role of kube-scheduler?
6. What is a Pod? Can a Pod contain multiple containers?
7. What is the difference between a Pod and a Deployment?
8. What is a Kubernetes Service?
9. How does Kubernetes recover when a container or Pod fails?
10. What is the difference between manual scaling and Horizontal Pod Autoscaling?

## 9. Practice Tasks

- [ ] Understand the difference between Docker and Kubernetes.
- [ ] Learn the responsibility of each Control Plane component.
- [ ] Learn the components of a Worker Node.
- [ ] Understand Cluster, Node, Pod, Deployment, and Service.
- [ ] Run the example `kubectl` commands in a practice cluster.
- [ ] Explain the e-commerce example in your own words.

---

**Day 01 Complete:** What is Kubernetes? Why do we need it? Architecture and use cases.

**Next:** Day 02 – Kubernetes Cluster Setup and Your First Deployment.
