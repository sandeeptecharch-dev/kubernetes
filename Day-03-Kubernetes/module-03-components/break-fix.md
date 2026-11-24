# Module 3: Break It and Fix It 💥

Five real problems, each caused by a different component. For each one, **diagnose before you read the fix**.

> ⚠️ **Only on your kind lab cluster.** Reset anytime:
> ```bash
> kind delete cluster --name techudaan
> kind create cluster --name techudaan --config ../module-01-architecture/kind-3node.yaml
> ```

**Before you start:** make sure the `web` Deployment and Service from [lab.md](lab.md) exist:

```bash
kubectl get deploy,svc web
```

Use this method for every exercise:

```
1. What is the symptom?  →  2. Which component owns it?  →  3. What does describe/logs say?  →  4. Fix  →  5. Verify
```

---

## Exercise 1: The Pod That Never Starts (Scheduler)

### 🔨 Break it

```bash
kubectl run payments --image=nginx --overrides='{"spec":{"nodeSelector":{"disk":"sdd"}}}'
kubectl get pod payments
```

### 🕵️ Diagnose

The Pod is `Pending`. Run `kubectl describe pod payments` and read the **Events**.
Which component left the message? What exactly does it say?

### 🔧 Fix it

<details>
<summary>Reveal the fix</summary>

The nodeSelector asks for `disk=sdd` (a typo). No node has that label, so the scheduler filters out every node.

```bash
kubectl delete pod payments
kubectl label node techudaan-worker2 disk=ssd
kubectl run payments --image=nginx --overrides='{"spec":{"nodeSelector":{"disk":"ssd"}}}'
kubectl get pod payments -o wide
```

**Lesson:** a `Pending` Pod with events = the scheduler is working and telling you why. Read the events.

</details>

---

## Exercise 2: "Could Not Resolve Host" (CoreDNS)

### 🔨 Break it

```bash
kubectl -n kube-system scale deployment coredns --replicas=0
kubectl run client --image=busybox:1.36 --rm -it --restart=Never -- wget -T 5 -qO- web
```

### 🕵️ Diagnose

The call fails. Is the `web` app broken? Try reaching it by IP instead:

```bash
kubectl get svc web
kubectl run client --image=busybox:1.36 --rm -it --restart=Never -- wget -T 5 -qO- <web-cluster-ip>
```

By IP it works, by name it fails. Which component turns names into IPs?

### 🔧 Fix it

<details>
<summary>Reveal the fix</summary>

```bash
kubectl -n kube-system scale deployment coredns --replicas=2
kubectl -n kube-system get pods -l k8s-app=kube-dns
kubectl run client --image=busybox:1.36 --rm -it --restart=Never -- wget -T 5 -qO- web
```

**Lesson:** works by IP but not by name = DNS. Always test both to narrow it down.

</details>

---

## Exercise 3: The Service With No Pods (Controllers + kube-proxy)

### 🔨 Break it

```bash
kubectl patch service web -p '{"spec":{"selector":{"app":"webb"}}}'
kubectl run client --image=busybox:1.36 --rm -it --restart=Never -- wget -T 5 -qO- web
```

### 🕵️ Diagnose

The Pods are running, DNS works, but the call fails. Check what's behind the Service:

```bash
kubectl get endpointslices -l kubernetes.io/service-name=web
kubectl describe service web | grep -iE "selector|endpoints"
kubectl get pods --show-labels | grep web
```

### 🔧 Fix it

<details>
<summary>Reveal the fix</summary>

The Service selector says `app=webb`, but the Pods are labelled `app=web`. The EndpointSlice controller finds no matching Pods, so kube-proxy has nowhere to send traffic.

```bash
kubectl patch service web -p '{"spec":{"selector":{"app":"web"}}}'
kubectl get endpointslices -l kubernetes.io/service-name=web
```

**Lesson:** a Service with no endpoints is almost always a label/selector mismatch. This is one of the most common real-world bugs.

</details>

---

## Exercise 4: The Pod That Won't Die (kubelet)

### 🔨 Break it

```bash
docker exec techudaan-worker2 sh -c 'cat > /etc/kubernetes/manifests/miner.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: miner
spec:
  containers:
    - name: miner
      image: busybox:1.36
      command: ["sh", "-c", "while true; do echo mining; sleep 5; done"]
EOF'
```

Wait 20 seconds. A suspicious Pod `miner-techudaan-worker2` appears. Your manager says: **"Remove it now."**

```bash
kubectl delete pod miner-techudaan-worker2
kubectl get pods | grep miner
```

### 🕵️ Diagnose

It keeps coming back. There's no Deployment or ReplicaSet. Check its owner:

```bash
kubectl get pod miner-techudaan-worker2 -o jsonpath='{.metadata.ownerReferences[0].kind}{"\n"}'
```

The owner is a `Node`. Who creates Pods without the API server telling them to?

### 🔧 Fix it

<details>
<summary>Reveal the fix</summary>

It's a **static Pod**. The kubelet runs it from a file, so only removing the file stops it.

```bash
docker exec techudaan-worker2 ls /etc/kubernetes/manifests
docker exec techudaan-worker2 rm /etc/kubernetes/manifests/miner.yaml
kubectl get pods | grep miner
```

**Lesson:** static Pods are also a real security concern. Someone with access to a node can run a Pod that `kubectl delete` can't remove.

</details>

---

## Exercise 5: Node Under Maintenance (Scheduler + Controllers)

### 🔨 Break it

```bash
kubectl cordon techudaan-worker
kubectl scale deployment web --replicas=6
kubectl get pods -l app=web -o wide
```

### 🕵️ Diagnose

All new Pods land on `techudaan-worker2`. Why is `techudaan-worker` ignored?

```bash
kubectl get nodes
```

### 🔧 Fix it

<details>
<summary>Reveal the fix</summary>

`cordon` marks the node `SchedulingDisabled`, so the scheduler filters it out. Existing Pods stay; new ones avoid it. This is how engineers prepare a node for maintenance (followed by `kubectl drain` to move existing Pods away).

```bash
kubectl uncordon techudaan-worker
kubectl scale deployment web --replicas=3
kubectl get nodes
```

**Lesson:** Kubernetes doesn't rebalance running Pods automatically when a node comes back. Only new Pods use it.

</details>

---

## 🏆 Your Debugging Cheat Sheet

| Symptom | Owner | First command |
|---|---|---|
| Pod `Pending` | Scheduler | `kubectl describe pod <name>` → Events |
| Works by IP, fails by name | CoreDNS | `kubectl -n kube-system get pods -l k8s-app=kube-dns` |
| Service has no endpoints | Selector / EndpointSlice | `kubectl get endpointslices -l kubernetes.io/service-name=<svc>` |
| Pod comes back after delete, no owner but a Node | kubelet (static Pod) | `ls /etc/kubernetes/manifests` on that node |
| Node skipped by scheduler | Cordon / taint | `kubectl get nodes`, `kubectl describe node` |

---

## ✅ Clean Up

```bash
kubectl delete pod payments
kubectl label node techudaan-worker2 disk-
```

Then test yourself with [quiz.md](quiz.md).
