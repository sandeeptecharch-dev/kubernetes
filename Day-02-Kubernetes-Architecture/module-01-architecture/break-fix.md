# Module 1: Break It and Fix It 💥

You understand a component best when you switch it off and watch what fails.

> ⚠️ **Do these only on your kind lab cluster, never on a real cluster.**
> If anything goes wrong, reset everything:
> ```bash
> kind delete cluster --name techudaan
> kind create cluster --name techudaan --config kind-3node.yaml
> ```

**Before you start:** finish [lab.md](lab.md) so the `web` Deployment is running.

---

## Exercise 1: The Scheduler Goes on Leave

### 🔨 Break it

Move the scheduler's static Pod file out of the manifests folder. The kubelet notices and stops the scheduler.

```bash
docker exec techudaan-control-plane mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/
```

Wait about 30 seconds, then:

```bash
kubectl get pods -n kube-system | grep scheduler
kubectl create deployment orphan --image=nginx --replicas=2
kubectl get pods -o wide
kubectl describe pod <one-orphan-pod-name>
```

### 👀 Observe

- The scheduler Pod is gone from `kube-system`
- The new `orphan` Pods stay `Pending`
- The `NODE` column shows `<none>`
- `kubectl describe` shows **no** `Scheduled` event
- The old `web` Pods keep running happily

### 🔧 Fix it

```bash
docker exec techudaan-control-plane mv /tmp/kube-scheduler.yaml /etc/kubernetes/manifests/
kubectl get pods -o wide -w
```

Press `Ctrl+C` once the `orphan` Pods are `Running`.

### ✍️ Explain in one line

Why did the old Pods survive while the new ones got stuck?

---

## Exercise 2: A Station Master Stops Working

### 🔨 Break it

Stop the kubelet on one worker node.

```bash
docker exec techudaan-worker systemctl stop kubelet
kubectl get nodes -w
```

### 👀 Observe

- Within about a minute, `techudaan-worker` becomes `NotReady`
- Run `kubectl describe node techudaan-worker` and find the message saying the kubelet stopped posting node status
- Wait about 5 minutes, then run `kubectl get pods -o wide`: Pods from `techudaan-worker` get replaced on `techudaan-worker2`

### 🔧 Fix it

```bash
docker exec techudaan-worker systemctl start kubelet
kubectl get nodes -w
```

Press `Ctrl+C` once the node is `Ready` again.

### ✍️ Explain in one line

Which component noticed the node was gone, and which one created the replacement Pods?

---

## 🏆 Challenge: The Front Door Closes

### 🔨 Break it

```bash
docker exec techudaan-control-plane mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
```

Wait about 30 seconds, then try:

```bash
kubectl get pods
```

Every `kubectl` command fails. Now check the worker directly:

```bash
docker exec techudaan-worker2 crictl ps | grep nginx
```

### 👀 Observe

Your nginx containers are **still running**, even though the API server is down.

### 🔧 Fix it

```bash
docker exec techudaan-control-plane mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
```

Wait 30 to 60 seconds, then confirm with `kubectl get nodes`.

### 💡 The lesson

The control plane **manages** your apps, but it doesn't carry their traffic.
A broken control plane means you can't change anything. It does **not** mean your app is down.

---

## ✅ Done?

Clean up the extra Deployment:

```bash
kubectl delete deployment orphan
```

Then test yourself with [quiz.md](quiz.md).
