# 30-Day Kubernetes Learning Roadmap

A practical, hands-on learning challenge to build Kubernetes skills from
fundamentals to production-oriented DevOps workflows.

> **Learning approach:** Learn the concept, understand why it is needed,
> practise it in a Kubernetes cluster, troubleshoot it, and explain it
> in your own words.

## Goals

By the end of this challenge, you should be able to:

-   Explain Kubernetes architecture and core components.
-   Deploy and manage containerized applications.
-   Work confidently with Kubernetes YAML manifests.
-   Configure service discovery, networking, and persistent storage.
-   Apply scheduling, resource management, health checks, and
    autoscaling.
-   Troubleshoot common workload and cluster issues.
-   Use Helm, monitoring tools, and CI/CD or GitOps workflows.
-   Deploy a small microservices application to Kubernetes.

## Lab Environment

Recommended tools:

-   Ubuntu or WSL2
-   Docker
-   KIND (Kubernetes IN Docker)
-   `kubectl`
-   Git and GitHub
-   A code editor such as Visual Studio Code

Optional tools introduced later:

-   Helm
-   NGINX Ingress Controller
-   Prometheus and Grafana
-   Jenkins
-   Argo CD

> Start with a local KIND cluster. Cloud Kubernetes services such as
> Amazon EKS or Azure AKS are optional extensions, not prerequisites for
> the first lessons.

## 30-Day Plan

### Phase 1 --- Kubernetes Fundamentals (Days 1--5)

  -------------------------------------------------------------------------
  Day                     Topic                   Practical activity
  ----------------------- ----------------------- -------------------------
  01                      What is Kubernetes? Why Explain the problem
                          do we need it?          Kubernetes solves and
                          Containers              identify where it fits in
                          vs. orchestration;      a DevOps workflow.
                          common use cases        

  02                      Kubernetes              Draw and explain how a
                          architecture: control   request flows through a
                          plane and worker nodes  Kubernetes cluster.

  03                      Kubernetes components:  Identify each component's
                          API server, scheduler,  responsibility and
                          controller manager,     inspect the local
                          etcd, kubelet and       cluster.
                          kube-proxy              

  04                      Local cluster setup     Install/check tools,
                          with KIND and kubectl   create a KIND cluster,
                                                  and run
                                                  `kubectl cluster-info`.

  05                      Clusters, nodes and     Inspect nodes, create a
                          namespaces              namespace, and list
                                                  resources by namespace.
  -------------------------------------------------------------------------

### Phase 2 --- Kubernetes Core Objects (Days 6--12)

  -----------------------------------------------------------------------
  Day                     Topic                   Practical activity
  ----------------------- ----------------------- -----------------------
  06                      Pods                    Create, inspect, view
                                                  logs from, and delete a
                                                  Pod.

  07                      YAML manifests          Write manifests, apply
                                                  them, inspect changes,
                                                  and delete resources.

  08                      ReplicaSets             Run multiple replicas
                                                  and observe how
                                                  Kubernetes maintains
                                                  the desired count.

  09                      Deployments             Deploy an application;
                                                  practise scaling,
                                                  rolling updates, and
                                                  rollbacks.

  10                      Services: ClusterIP,    Expose an application
                          NodePort and            and test connectivity
                          LoadBalancer            between resources.

  11                      Labels, selectors and   Label resources and use
                          annotations             selectors to find and
                                                  group them.

  12                      ConfigMaps and Secrets  Inject configuration
                                                  and sensitive values
                                                  into a workload;
                                                  discuss safe secret
                                                  handling.
  -----------------------------------------------------------------------

### Phase 3 --- Networking, Storage and Scheduling (Days 13--19)

  ------------------------------------------------------------------------
  Day                     Topic                    Practical activity
  ----------------------- ------------------------ -----------------------
  13                      Kubernetes networking    Explore Pod IPs,
                          fundamentals             Service IPs, and
                                                   communication between
                                                   Pods.

  14                      CoreDNS and service      Resolve a Service by
                          discovery                DNS name from another
                                                   Pod.

  15                      Ingress and Ingress      Install an Ingress
                          Controller               Controller and route
                                                   HTTP traffic to a
                                                   Service.

  16                      PersistentVolumes (PV)   Create a claim and
                          and                      mount persistent
                          PersistentVolumeClaims   storage in a Pod.
                          (PVC)                    

  17                      StorageClasses and       Inspect available
                          dynamic provisioning     StorageClasses and
                                                   understand dynamic
                                                   volume provisioning.

  18                      Resource requests,       Set CPU and memory
                          limits and QoS           requests/limits and
                                                   inspect Pod behaviour.

  19                      Scheduling: node         Influence where
                          selectors, taints,       workloads are scheduled
                          tolerations and affinity and verify placement.
  ------------------------------------------------------------------------

### Phase 4 --- Advanced Kubernetes (Days 20--25)

  -----------------------------------------------------------------------
  Day                     Topic                   Practical activity
  ----------------------- ----------------------- -----------------------
  20                      StatefulSets            Deploy a stateful
                                                  workload and examine
                                                  stable Pod identities
                                                  and storage.

  21                      DaemonSets and Jobs     Run a Pod on eligible
                                                  nodes with a DaemonSet
                                                  and execute a one-time
                                                  Job.

  22                      CronJobs and Init       Schedule a recurring
                          Containers              task and run
                                                  initialization before
                                                  the main container.

  23                      Liveness, readiness and Configure probes and
                          startup probes          observe how Kubernetes
                                                  responds to failed
                                                  checks.

  24                      Horizontal Pod          Configure autoscaling
                          Autoscaler (HPA)        and understand its
                                                  metrics requirements.

  25                      RBAC, ServiceAccounts   Create a limited-access
                          and SecurityContext     identity and practise
                                                  least-privilege
                                                  permissions.
  -----------------------------------------------------------------------

### Phase 5 --- Production and DevOps Practices (Days 26--30)

  -----------------------------------------------------------------------
  Day                     Topic                   Practical activity
  ----------------------- ----------------------- -----------------------
  26                      Troubleshooting         Diagnose Pending Pods,
                          Kubernetes              CrashLoopBackOff,
                                                  ImagePullBackOff,
                                                  failed probes, and
                                                  service connectivity
                                                  issues.

  27                      Helm charts             Install a chart,
                                                  inspect its values, and
                                                  package a simple
                                                  application.

  28                      Monitoring with         Deploy or explore
                          Prometheus and Grafana  monitoring components
                                                  and inspect
                                                  application/cluster
                                                  metrics.

  29                      CI/CD and GitOps with   Understand a
                          Jenkins and Argo CD     build-to-deploy
                                                  pipeline and practise a
                                                  Git-driven deployment
                                                  workflow.

  30                      End-to-end              Deploy a small
                          microservices project   multi-service
                                                  application and
                                                  document its
                                                  architecture,
                                                  deployment, and
                                                  troubleshooting.
  -----------------------------------------------------------------------

## Capstone Project --- Deploy a Microservices Application

Build and deploy a sample e-commerce-style application. Keep the first
version simple; add production-style features incrementally.

Suggested components:

-   Frontend
-   User service
-   Order service
-   Notification service
-   Database (for example, MongoDB)
-   Kubernetes Deployments and Services
-   ConfigMaps and Secrets
-   Ingress-based HTTP routing
-   Persistent storage where appropriate
-   Resource requests and limits
-   Health probes
-   Monitoring with Prometheus and Grafana
-   A CI/CD or GitOps deployment workflow

### Suggested project milestones

1.  Containerize the application services.
2.  Create Kubernetes manifests for Deployments and Services.
3.  Configure application settings using ConfigMaps and Secrets.
4.  Add ingress routing and service-to-service communication.
5.  Add persistent storage for the database, if used.
6.  Configure probes and resource requests/limits.
7.  Deploy monitoring and inspect metrics.
8.  Automate deployment and document rollback and troubleshooting steps.

## Daily Learning Routine

Use this routine for each study session:

1.  **Understand** --- Learn what the concept is and why it exists.
2.  **Visualize** --- Draw the architecture or request flow.
3.  **Practise** --- Run commands and create the required YAML files.
4.  **Verify** --- Inspect resources, events, logs, and application
    behaviour.
5.  **Troubleshoot** --- Intentionally test a failure where safe, then
    diagnose it.
6.  **Explain** --- Write a short summary in your own words.
7.  **Review** --- Answer a few interview questions based on the day's
    topic.

Recommended time: **1--2 hours per day**. Spend more time on hands-on
practice when a concept is unfamiliar.

## Progress Tracker

Tick each day after completing its practical activity and writing a
short summary.

-   [ ] Day 01 --- Kubernetes introduction
-   [ ] Day 02 --- Architecture
-   [ ] Day 03 --- Components
-   [ ] Day 04 --- KIND and kubectl setup
-   [ ] Day 05 --- Clusters, nodes and namespaces
-   [ ] Day 06 --- Pods
-   [ ] Day 07 --- YAML manifests
-   [ ] Day 08 --- ReplicaSets
-   [ ] Day 09 --- Deployments
-   [ ] Day 10 --- Services
-   [ ] Day 11 --- Labels, selectors and annotations
-   [ ] Day 12 --- ConfigMaps and Secrets
-   [ ] Day 13 --- Networking fundamentals
-   [ ] Day 14 --- CoreDNS and service discovery
-   [ ] Day 15 --- Ingress
-   [ ] Day 16 --- PV and PVC
-   [ ] Day 17 --- StorageClasses
-   [ ] Day 18 --- Requests, limits and QoS
-   [ ] Day 19 --- Scheduling
-   [ ] Day 20 --- StatefulSets
-   [ ] Day 21 --- DaemonSets and Jobs
-   [ ] Day 22 --- CronJobs and Init Containers
-   [ ] Day 23 --- Health probes
-   [ ] Day 24 --- HPA
-   [ ] Day 25 --- RBAC and security
-   [ ] Day 26 --- Troubleshooting
-   [ ] Day 27 --- Helm
-   [ ] Day 28 --- Prometheus and Grafana
-   [ ] Day 29 --- Jenkins CI/CD and Argo CD GitOps
-   [ ] Day 30 --- Capstone project

## Useful Commands to Start With

``` bash
# Check kubectl version
kubectl version --client

# Check cluster information
kubectl cluster-info

# List nodes
kubectl get nodes

# List namespaces
kubectl get namespaces

# Create a namespace
kubectl create namespace learning

# Run a test Pod
kubectl run nginx --image=nginx:latest --restart=Never -n learning

# List Pods in the learning namespace
kubectl get pods -n learning

# Inspect a Pod
kubectl describe pod nginx -n learning

# View Pod logs
kubectl logs nginx -n learning

# Delete the test Pod
kubectl delete pod nginx -n learning
```

## Important Notes

-   This roadmap is a learning sequence, not a Kubernetes certification
    syllabus.
-   Some topics depend on cluster configuration. For example, a
    LoadBalancer Service, dynamic storage provisioning, metrics-based
    HPA, and Ingress require the relevant controller, provisioner,
    metrics source, or local-cluster integration.
-   KIND is excellent for local practice, but it does not automatically
    reproduce every cloud-provider feature.
-   Never commit real credentials, tokens, certificates, or production
    secrets to a public repository.
-   Use disposable lab resources and verify commands before running them
    against production clusters.

## Learning Outcome

At the end of 30 days, you should have a working understanding of
Kubernetes fundamentals and practical experience deploying, exposing,
configuring, monitoring, and troubleshooting containerized workloads.

**Learn • Practise • Build • Troubleshoot • Grow**

#30DaysOfKubernetes #Kubernetes #DevOps #CloudNative #Docker #SRE
