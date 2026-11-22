# Day 02: Kubernetes Architecture -- Control Plane and Worker Nodes

Welcome to **Day 02** of the 30 Days of Kubernetes Learning Challenge!

In Day 01, we learned what Kubernetes is, why we need it, and the
problems it solves. Today, we will understand the architecture of a
Kubernetes cluster and how the Control Plane and Worker Nodes work
together to run applications.

## 1. What Is Kubernetes Architecture?

Kubernetes architecture is based on a **Control Plane** and one or more
**Worker Nodes**.

-   **Control Plane:** Manages the cluster and makes decisions about
    scheduling and maintaining applications.
-   **Worker Nodes:** Provide the compute environment where application
    Pods run.

Think of the Control Plane as the brain of the cluster and Worker Nodes
as the machines that do the actual application work.

## 2. Control Plane Components

The Control Plane manages the overall state of the Kubernetes cluster.

  -----------------------------------------------------------------------
  Component                           Responsibility
  ----------------------------------- -----------------------------------
  **kube-apiserver**                  Exposes the Kubernetes API and acts
                                      as the main entry point for cluster
                                      operations.

  **etcd**                            Stores Kubernetes cluster data,
                                      including configuration and state.

  **kube-scheduler**                  Selects a suitable Worker Node for
                                      newly created, unscheduled Pods.

  **kube-controller-manager**         Runs controllers that continuously
                                      work to move the cluster toward its
                                      desired state.

  **cloud-controller-manager** *(when Integrates the cluster with a cloud
  used)*                              provider's APIs and services.
  -----------------------------------------------------------------------

### How the Control Plane works

When you apply a Deployment manifest:

1.  `kubectl` sends the request to the API Server.
2.  The API Server validates and processes the request.
3.  The desired cluster state is stored in etcd.
4.  The controllers notice that the requested replicas need to be
    created.
5.  The Scheduler assigns each new Pod to a suitable Worker Node.
6.  The kubelet on the selected node works with the container runtime to
    start the containers.

The Control Plane components coordinate this process; they do not
normally run your application containers.

## 3. Worker Node Components

Worker Nodes are responsible for running application workloads.

  -----------------------------------------------------------------------
  Component                           Responsibility
  ----------------------------------- -----------------------------------
  **kubelet**                         Communicates with the API Server
                                      and makes sure the Pods assigned to
                                      its node are running as specified.

  **Container Runtime**               Pulls images and runs containers.
                                      Examples include containerd and
                                      CRI-O.

  **kube-proxy** *(when deployed)*    Implements Service networking rules
                                      on the node. Some networking
                                      implementations provide this
                                      functionality differently.

  **Pods**                            The smallest deployable units in
                                      Kubernetes. A Pod contains one or
                                      more closely related containers.
  -----------------------------------------------------------------------

## 4. Real-World Example: E-commerce Application

Imagine an e-commerce platform with these microservices:

-   Product Service
-   User Service
-   Order Service
-   Payment Service
-   Notification Service

During a sale, thousands of customers may access the platform at the
same time.

Kubernetes helps manage these workloads. For example, we can request
three replicas of the Order Service:

``` yaml
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
        - name: order-service
          image: nginx:1.27
          ports:
            - containerPort: 80
```

> **Note:** `nginx:1.27` is used here as a simple illustrative container
> image. Replace it with your actual Order Service image when deploying
> your application.

Kubernetes works to maintain the requested three replicas. If a Pod
fails, the relevant controllers detect the difference between the
desired and observed state and work to create a replacement. The
replacement may run on the same or another suitable node.

## 5. What Happens If the Control Plane Goes Down?

This is an important production and interview question.

If the Control Plane becomes unavailable:

-   Already-running containers on Worker Nodes generally continue
    running.
-   New deployments, scheduling decisions, and many management
    operations may be unavailable.
-   Nodes may temporarily continue operating with their existing local
    state.
-   Recovery and ongoing cluster management depend on restoring Control
    Plane availability.

For production environments, the Control Plane should be designed for
high availability. Managed Kubernetes services often provide much of
this infrastructure management.

## 6. Control Plane vs Worker Nodes

  -----------------------------------------------------------------------
  Control Plane                       Worker Nodes
  ----------------------------------- -----------------------------------
  Manages the cluster                 Runs application workloads

  Runs API Server, etcd, Scheduler    Runs kubelet and a container
  and controllers                     runtime

  Makes scheduling and reconciliation Hosts Pods
  decisions                           

  Maintains the desired cluster state Reports node and workload status
  -----------------------------------------------------------------------

## 7. Key Takeaways

-   Control Plane = Brain of the Kubernetes cluster.
-   Worker Nodes = Machines that run application workloads.
-   API Server = Main Kubernetes API entry point.
-   etcd = Stores cluster data.
-   Scheduler = Selects nodes for Pods.
-   Controller Manager = Reconciles actual state toward desired state.
-   kubelet = Ensures assigned Pods are running.
-   Container Runtime = Runs containers.
-   Pod = Smallest deployable Kubernetes unit.

## 8. Quick Interview Questions

1.  What is the difference between the Control Plane and a Worker Node?
2.  What is the role of the API Server?
3.  Why does Kubernetes use etcd?
4.  What does the Scheduler do?
5.  What is the responsibility of kubelet?
6.  What happens to running applications if the Control Plane becomes
    unavailable?
7.  What is the difference between a Pod and a container?

## 9. Practice Task

Try these commands on your Kubernetes cluster:

``` bash
# View cluster information
kubectl cluster-info

# List all nodes
kubectl get nodes -o wide

# View system Pods
kubectl get pods -n kube-system

# View detailed information about a node
kubectl describe node <node-name>

# View all Pods across namespaces
kubectl get pods -A
```

Observe which components are running in the `kube-system` namespace. The
exact components depend on your Kubernetes distribution and cluster
configuration.

## Day 02 Summary

Today, we explored how Kubernetes is structured and how its Control
Plane coordinates Worker Nodes to run containerized applications.

**Remember:** The Control Plane decides and coordinates; Worker Nodes
execute the workloads.

------------------------------------------------------------------------

**30 Days of Kubernetes Learning Challenge -- Day 02**

Learn • Build • Grow

#Kubernetes #DevOps #KubernetesArchitecture #CloudNative #Docker
#LearningInPublic #TechUdaan
