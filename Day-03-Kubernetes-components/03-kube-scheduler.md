# 03. kube-scheduler: The Matchmaker

> The scheduler decides **where** each Pod runs. It never starts a container itself.

⬅️ Previous: [02. etcd](02-etcd.md) | ➡️ Next: [04. kube-controller-manager](04-kube-controller-manager.md)

---

## 1. What Is It?

When a new Pod is created, it has **no node** yet. Its `spec.nodeName` is empty, and its status is `Pending`.

The kube-scheduler watches for these Pods, picks the **best node** for each one, and writes that node's name into the Pod. That's all. Then the **kubelet** on that node starts the containers.

**Scheduler = decides. kubelet = does.**

---

## 2. Real-Life Analogy 🚆

The scheduler is the **platform allocation officer** at a big station.

- A new train arrives. The officer checks which platforms are **free**, which are **long enough**, and which are **closed for repairs**.
- Out of the suitable ones, they pick the **best** (least crowded).
- They announce the platform. The **station master** (kubelet) handles everything after that.

---

## 3. How It Works

The scheduler decides in **2 phases**:

```
                 New Pod (nodeName empty)
                          │
                          ▼
   ┌─────────────────────────────────────────────┐
   │ PHASE 1: FILTER (remove nodes that can't)   │
   │  ✗ Not enough CPU / memory for requests     │
   │  ✗ nodeSelector / affinity doesn't match    │
   │  ✗ Taint the Pod doesn't tolerate           │
   │  ✗ Node cordoned (SchedulingDisabled)       │
   └──────────────────────┬──────────────────────┘
                          ▼  nodes that CAN run it
   ┌─────────────────────────────────────────────┐
   │ PHASE 2: SCORE (rank the rest)              │
   │  + More free resources                      │
   │  + Spreads Pods of the same app             │
   │  + Image already on the node                │
   └──────────────────────┬──────────────────────┘
                          ▼
         Highest score wins → writes nodeName
                          ▼
              kubelet on that node starts it
```

If **no node passes the filter**, the Pod stays `Pending`, and the scheduler records the reason as an **event**.

---

## 4. Key Facts to Remember

| Fact | Why it matters |
|---|---|
| Schedules using **requests**, not real usage | A Pod asking for 4 CPUs needs 4 free CPUs on paper, even if it uses 0.1 |
| Control-plane nodes have a **taint** | That's why your app Pods never land there |
| Setting `spec.nodeName` yourself **skips the scheduler** | Useful to understand, rarely used in real life |
| Scheduler down → new Pods stay `Pending` with **no events** | Existing Pods are unaffected |
| Runs as a **static Pod**, with leader election | In HA setups only one copy is active at a time |

---

## 5. Practical 🧪

**Setup:**

```bash
kubectl create deployment web --image=nginx --replicas=3 2>/dev/null || true
```

### Step 1: Find the scheduler

```bash
kubectl get pods -n kube-system -l component=kube-scheduler -o wide
```

**What this proves:** the scheduler is a static Pod on the control-plane node.

### Step 2: See the scheduler's decisions

```bash
kubectl get events --field-selector reason=Scheduled --sort-by=.metadata.creationTimestamp | tail -5
```

**Expected (something like):**

```
Normal  Scheduled  pod/web-7d9f8c-abc12  Successfully assigned default/web-7d9f8c-abc12 to techudaan-worker
```

**What this proves:** every `Scheduled` event is the scheduler writing a node name into a Pod.

### Step 3: Watch it spread Pods (scoring)

```bash
kubectl scale deployment web --replicas=6
sleep 10
kubectl get pods -l app=web -o wide --no-headers | awk '{print $7}' | sort | uniq -c
```

**Expected:** roughly 3 Pods on each worker, and **none** on the control plane.

**What this proves:** the scoring phase spreads copies of the same app across nodes, so one node failing doesn't take down every copy.

### Step 4: Why nothing runs on the control plane (taints)

```bash
kubectl describe node techudaan-control-plane | grep -i taints
```

**Expected:**

```
Taints:  node-role.kubernetes.io/control-plane:NoSchedule
```

**What this proves:** a **taint** repels Pods. Your Pods don't **tolerate** it, so the filter phase removes this node.

### Step 5: Choose a node with a label (nodeSelector)

```bash
kubectl label node techudaan-worker2 disk=ssd
kubectl run fast-app --image=nginx --overrides='{"spec":{"nodeSelector":{"disk":"ssd"}}}'
kubectl get pod fast-app -o wide
```

**Expected:** `fast-app` runs on `techudaan-worker2`. Delete and recreate it: same node, every time.

**What this proves:** `nodeSelector` is a **filter**. Only nodes with matching labels survive phase 1.

### Step 6: Ask for more than any node has

```bash
kubectl run greedy --image=nginx \
  --overrides='{"spec":{"containers":[{"name":"greedy","image":"nginx","resources":{"requests":{"cpu":"100"}}}]}}'
kubectl get pod greedy
kubectl describe pod greedy | grep -A3 Events
```

**Expected:**

```
Warning  FailedScheduling  ...  0/3 nodes are available: 1 node(s) had untolerated taint ..., 2 Insufficient cpu. ...
```

**What this proves:** read this message like the scheduler's report card. It tells you **why each node was filtered out**.

### Step 7: Taint a worker for "maintenance"

```bash
kubectl taint node techudaan-worker maintenance=true:NoSchedule
kubectl scale deployment web --replicas=8
sleep 10
kubectl get pods -l app=web -o wide --no-headers | awk '{print $7}' | sort | uniq -c
```

**Expected:** the existing Pods stay where they are, but all **new** Pods go to `techudaan-worker2`.

Now create a Pod that **tolerates** the taint:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tolerant
spec:
  nodeSelector:
    kubernetes.io/hostname: techudaan-worker
  tolerations:
    - key: maintenance
      operator: Equal
      value: "true"
      effect: NoSchedule
  containers:
    - name: nginx
      image: nginx
EOF
kubectl get pod tolerant -o wide
```

**Expected:** `tolerant` runs on the tainted `techudaan-worker`.

**What this proves:** taints repel Pods; tolerations let specific Pods through. `NoSchedule` doesn't affect Pods already running.

### Step 8: Skip the scheduler entirely

```bash
kubectl run manual --image=nginx --overrides='{"spec":{"nodeName":"techudaan-worker2"}}'
kubectl get pod manual -o wide
kubectl get events --field-selector involvedObject.name=manual | grep -c Scheduled
```

**Expected:** the Pod runs on `techudaan-worker2`, and the count of `Scheduled` events is **0**.

**What this proves:** if `nodeName` is already set, the scheduler has nothing to do. The kubelet just starts it.

### Clean up

```bash
kubectl delete pod fast-app greedy tolerant manual
kubectl taint node techudaan-worker maintenance=true:NoSchedule-
kubectl label node techudaan-worker2 disk-
kubectl scale deployment web --replicas=3
```

---

## 6. Break It and Fix It 💥

> ⚠️ Lab cluster only.

**Break:** stop the scheduler.

```bash
docker exec techudaan-control-plane mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/
sleep 30
kubectl create deployment orphan --image=nginx --replicas=2
kubectl get pods -l app=orphan -o wide
kubectl describe pod -l app=orphan | grep -A3 Events
```

**Observe:** `Pending`, `NODE` is `<none>`, and **no events at all**. Compare with Step 6, where the scheduler explained exactly why.

**Fix:**

```bash
docker exec techudaan-control-plane mv /tmp/kube-scheduler.yaml /etc/kubernetes/manifests/
kubectl get pods -l app=orphan -o wide -w
```

Press `Ctrl+C` once they're `Running`, then `kubectl delete deployment orphan`.

**Lesson:** `Pending` **with** events = the scheduler is working; read its reason. `Pending` with **no** events = the scheduler itself is down.

---

## 7. Common Errors

| Event message | Meaning | Fix |
|---|---|---|
| `Insufficient cpu` / `Insufficient memory` | Requests bigger than free capacity | Lower requests or add nodes |
| `didn't match Pod's node affinity/selector` | No node has the required label | Fix the label or the selector |
| `had untolerated taint` | Node has a taint the Pod doesn't tolerate | Add a toleration or remove the taint |
| `node(s) were unschedulable` | Node is cordoned | `kubectl uncordon <node>` |
| No events at all | Scheduler isn't running | Check the scheduler Pod in `kube-system` |

---

## 8. Interview Questions 🎤

1. Does the scheduler start containers?
2. Explain the two phases of scheduling.
3. A Pod is `Pending` with `Insufficient cpu`, but the node's real CPU usage is only 10%. Why?
4. Why don't application Pods run on the control-plane node?
5. What's the difference between a taint and a nodeSelector?

<details>
<summary>Answers</summary>

1. No. It only sets `nodeName`. The kubelet on that node starts the containers.
2. **Filter:** remove nodes that can't run the Pod. **Score:** rank the remaining nodes and pick the highest.
3. The scheduler uses **requests**, not real usage. Other Pods have already reserved (requested) the CPU.
4. The control-plane node has a `NoSchedule` taint that normal Pods don't tolerate.
5. A **nodeSelector** is the Pod saying "I want nodes with this label". A **taint** is the node saying "keep away unless you tolerate me".

</details>

---

## ✅ Recap

- The scheduler **only decides**: it fills in `nodeName`. The kubelet runs the Pod.
- It works in two phases: **filter**, then **score**. It uses **requests**, not real usage.
- `Pending` with events = read the reason. `Pending` without events = the scheduler is down.

➡️ Next: [04. kube-controller-manager, the fixer](04-kube-controller-manager.md)
