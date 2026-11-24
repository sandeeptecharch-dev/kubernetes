# Module 1 Lab: Find Every Component on Your Laptop

⏱️ **Time:** about 45 minutes
🎯 **Goal:** build a 3-node cluster with kind (Kubernetes in Docker) and see every component from [notes.md](notes.md) running.
💰 **Cost:** free

---

## Before You Start

- [ ] Docker is running (Docker Desktop, or Docker Engine inside WSL2 on Windows)
- [ ] [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) is installed: `kind version`
- [ ] [kubectl](https://kubernetes.io/docs/tasks/tools/) is installed: `kubectl version --client`

> 💡 On an 8 GB laptop, close heavy browser tabs. If it's still slow, remove the last `worker` line in [kind-3node.yaml](kind-3node.yaml) for a 2-node cluster.

---

## Step 1: Create the Cluster

From this folder, run:

```bash
kind create cluster --name techudaan --config kind-3node.yaml
kubectl cluster-info
kubectl get nodes -o wide
```

✅ **Expected:** 3 nodes, all `Ready`:

```
NAME                      STATUS   ROLES           AGE   VERSION
techudaan-control-plane   Ready    control-plane   1m    v1.x.x
techudaan-worker          Ready    <none>          1m    v1.x.x
techudaan-worker2         Ready    <none>          1m    v1.x.x
```

---

## Step 2: See That Nodes Are Just Containers

In kind, each "machine" is a Docker container.

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

✅ **Expected:** three containers named `techudaan-control-plane`, `techudaan-worker` and `techudaan-worker2`.

---

## Step 3: Find the Control Plane

```bash
kubectl get pods -n kube-system -o wide
```

Match each Pod to a component from the notes:

| Pod name starts with | Component | Runs on |
|---|---|---|
| `kube-apiserver-` | API server | control-plane node |
| `etcd-` | etcd | control-plane node |
| `kube-scheduler-` | Scheduler | control-plane node |
| `kube-controller-manager-` | Controller manager | control-plane node |
| `kube-proxy-` | kube-proxy | every node (one each) |
| `kindnet-` | CNI network plugin | every node (one each) |
| `coredns-` | CoreDNS | usually 2 copies |

✍️ **Write down:** how many `kube-proxy` Pods do you see, and why that number?

---

## Step 4: Discover Static Pods

The control-plane Pods are started by the kubelet directly from files on disk, not through the scheduler. These are called **static Pods**. Look at those files:

```bash
docker exec techudaan-control-plane ls /etc/kubernetes/manifests
```

✅ **Expected:** `etcd.yaml`, `kube-apiserver.yaml`, `kube-controller-manager.yaml`, `kube-scheduler.yaml`

✍️ **Think:** why can't the scheduler schedule itself?

---

## Step 5: Meet the kubelet and the Runtime

The kubelet is **not** a Pod. It runs as a normal service on each node.

```bash
docker exec techudaan-worker systemctl status kubelet --no-pager
docker exec techudaan-worker crictl ps
```

✅ **Expected:** the kubelet shows `active (running)`, and `crictl ps` lists the containers that containerd is running on that node.

---

## Step 6: Watch the Deployment Journey

```bash
kubectl create deployment web --image=nginx --replicas=3
kubectl get pods -o wide
kubectl get events --sort-by=.metadata.creationTimestamp
```

In the events, find these and match them to the steps in [notes.md, section 5](notes.md#5-what-happens-when-you-deploy-an-app):

| Event | Component | Journey step |
|---|---|---|
| `ScalingReplicaSet` | Deployment controller | 4 |
| `SuccessfulCreate` | ReplicaSet controller | 5 |
| `Scheduled` | Scheduler | 6 |
| `Pulling` / `Pulled` | Container runtime | 8 |
| `Started` | kubelet | 9 |

---

## Step 7: Watch Self-Healing

```bash
kubectl get pods
kubectl delete pod <one-of-the-web-pod-names>
kubectl get pods
```

✅ **Expected:** a new Pod with a different name appears within seconds. There are always 3.

✍️ **Write down:** which component created the new Pod?

---

## ✅ Lab Complete When...

- [ ] You can point at every row of the Step 3 table and say what it does, **without looking at the notes**
- [ ] You can explain why control-plane Pods are static Pods
- [ ] You watched self-healing happen

Keep the cluster running. You need it for [break-fix.md](break-fix.md).

---

## 🧹 Clean Up (when you're done with the whole module)

```bash
kind delete cluster --name techudaan
```
