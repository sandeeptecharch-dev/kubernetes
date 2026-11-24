# 04. kube-controller-manager: The Fixer

> You declare what you want. The controllers make it happen, and keep it that way, forever.

⬅️ Previous: [03. kube-scheduler](03-kube-scheduler.md) | ➡️ Next: [05. kubelet](05-kubelet.md)

---

## 1. What Is It?

The kube-controller-manager is **one program that runs many controllers** inside it. Each controller looks after one type of object.

Every controller runs the same simple loop, forever:

1. **Observe:** what is actually running right now?
2. **Compare:** what did the user ask for (desired state)?
3. **Act:** if they differ, fix it.

This loop is called **reconciliation**, and it's the heart of Kubernetes. It's why a deleted Pod comes back, and why a Deployment updates itself when you change the image.

---

## 2. Real-Life Analogy 🚆

The controllers are **station inspectors** walking their rounds all day.

- One inspector only checks **coach counts**: "Train 12951 should have 20 coaches. It has 19. Attach one."
- Another only checks **platforms**: "Platform 3's station master hasn't reported in 5 minutes. Move its trains elsewhere."
- They never stop. They don't wait for complaints. They keep checking reality against the plan.

---

## 3. How It Works

```
               ┌───────────────────────────────┐
               │   desired state (in etcd)     │
               │   "web: 3 replicas"           │
               └──────────────┬────────────────┘
                              │ compare
   ┌──────────────────────────▼─────────────────────────────┐
   │              RECONCILIATION LOOP (forever)             │
   │                                                        │
   │   OBSERVE  ──►  COMPARE  ──►  ACT  ──► (repeat)        │
   │   "2 Pods       "3 wanted,     "create                 │
   │    running"      2 exist"       1 Pod"                 │
   └────────────────────────────────────────────────────────┘
```

### Controllers you'll meet first

| Controller | Watches | What it does |
|---|---|---|
| **Deployment** | Deployments | Creates a ReplicaSet; manages rolling updates and rollbacks |
| **ReplicaSet** | ReplicaSets | Keeps exactly N Pods running |
| **Node lifecycle** | Node heartbeats | Marks dead nodes `NotReady`; evicts their Pods |
| **Job** | Jobs | Runs Pods until a task completes successfully |
| **EndpointSlice** | Services + Pods | Keeps the list of Pod IPs behind each Service up to date |
| **Namespace** | Namespaces | Deletes everything inside a namespace when it's deleted |
| **ServiceAccount** | Namespaces | Creates a `default` service account in each new namespace |
| **Garbage collector** | `ownerReferences` | Deletes children when their parent is deleted |

### The family tree

```
Deployment "web"
   └── ReplicaSet "web-7d9f8c"          (created by the Deployment controller)
         ├── Pod "web-7d9f8c-abc12"     (created by the ReplicaSet controller)
         ├── Pod "web-7d9f8c-def34"
         └── Pod "web-7d9f8c-ghi56"
```

Each child stores its parent's name in `metadata.ownerReferences`. That's how the garbage collector knows what to delete.

---

## 4. Key Facts to Remember

| Fact | Why it matters |
|---|---|
| One process, **many controllers** | Simpler to run and deploy |
| Controllers **never talk to each other** | They each watch the API server and react |
| **Level-triggered**: compares state, not events | If it misses an event, it still fixes things on the next check |
| Runs with **leader election** | In HA clusters only one copy acts at a time; others wait |
| Runs as a **static Pod** on the control plane | Defined in `/etc/kubernetes/manifests/kube-controller-manager.yaml` |

---

## 5. Practical 🧪

**Setup:**

```bash
kubectl create deployment web --image=nginx --replicas=3 2>/dev/null || true
```

### Step 1: Find it and see which controllers it runs

```bash
kubectl get pods -n kube-system -l component=kube-controller-manager
docker exec techudaan-control-plane grep -- "--controllers" /etc/kubernetes/manifests/kube-controller-manager.yaml
```

**Expected:** `--controllers=*,bootstrapsigner,tokencleaner`. The `*` means "all default controllers".

### Step 2: Desired state vs actual state

```bash
kubectl get deployment web -o jsonpath='desired={.spec.replicas} ready={.status.readyReplicas}{"\n"}'
```

**Expected:** `desired=3 ready=3`. The controllers' job is to keep these two numbers equal.

### Step 3: Self-healing in action

Open **two terminals**.

**Terminal 1:**

```bash
kubectl get pods -l app=web -w
```

**Terminal 2**, delete a Pod:

```bash
kubectl delete pod $(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}')
```

**Expected (Terminal 1):** one Pod goes `Terminating`, and almost immediately a new Pod with a different name goes `Pending` → `ContainerCreating` → `Running`.

**What this proves:** the ReplicaSet controller noticed 2 ≠ 3 and created a replacement. You didn't ask it to; it just reconciled.

### Step 4: Trace the family tree

```bash
kubectl get deploy,rs,pods -l app=web

POD=$(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}')
RS=$(kubectl get pod $POD -o jsonpath='{.metadata.ownerReferences[0].name}')

echo "Pod $POD is owned by: $(kubectl get pod $POD -o jsonpath='{.metadata.ownerReferences[0].kind}') $RS"
echo "ReplicaSet $RS is owned by: $(kubectl get rs $RS -o jsonpath='{.metadata.ownerReferences[0].kind} {.metadata.ownerReferences[0].name}')"
```

**Expected:**

```
Pod web-7d9f8c-abc12 is owned by: ReplicaSet web-7d9f8c
ReplicaSet web-7d9f8c is owned by: Deployment web
```

**What this proves:** Pods aren't created by the Deployment directly. Deployment → ReplicaSet → Pods, each made by a different controller.

### Step 5: Garbage collection

```bash
kubectl create deployment temp --image=nginx --replicas=2
sleep 10
kubectl get deploy,rs,pods -l app=temp
kubectl delete deployment temp
sleep 5
kubectl get rs,pods -l app=temp
```

**Expected:** after deleting the Deployment, its ReplicaSet and Pods are gone too.

Now try it **without** the cascade:

```bash
kubectl create deployment temp --image=nginx --replicas=2
sleep 10
kubectl delete deployment temp --cascade=orphan
kubectl get rs,pods -l app=temp
```

**Expected:** the Deployment is gone, but the ReplicaSet and Pods are **still running**, now orphaned.

```bash
kubectl delete rs -l app=temp
```

**What this proves:** the garbage collector follows `ownerReferences` to clean up children, unless you tell it not to.

### Step 6: The Job controller

```bash
kubectl create job hello --image=busybox:1.36 -- sh -c 'echo "Hello from TechUdaan"; sleep 5'
kubectl get jobs,pods -l job-name=hello -w
```

Press `Ctrl+C` when the Pod is `Completed`.

```bash
kubectl logs job/hello
kubectl delete job hello
```

**What this proves:** a different controller with a different goal. The ReplicaSet controller keeps Pods **running forever**; the Job controller runs Pods until they **finish successfully**.

### Step 7: The EndpointSlice controller

```bash
kubectl expose deployment web --port=80 2>/dev/null || true
kubectl get endpointslices -l kubernetes.io/service-name=web
kubectl scale deployment web --replicas=5
sleep 10
kubectl get endpointslices -l kubernetes.io/service-name=web
kubectl scale deployment web --replicas=3
```

**Expected:** the list of IPs grows from 3 to 5 automatically.

**What this proves:** a controller keeps each Service's list of Pod IPs up to date, so traffic always goes to Pods that actually exist.

### Step 8: Leader election

```bash
kubectl get lease kube-controller-manager -n kube-system -o jsonpath='{.spec.holderIdentity}{"\n"}'
```

**What this proves:** a Lease object records which copy is the active leader. In a 3-control-plane cluster, if the leader dies, another copy takes over.

---

## 6. Break It and Fix It 💥

> ⚠️ Lab cluster only.

**Break:** stop the controller manager.

```bash
docker exec techudaan-control-plane mv /etc/kubernetes/manifests/kube-controller-manager.yaml /tmp/
sleep 30
kubectl delete pod $(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}')
kubectl get pods -l app=web
kubectl scale deployment web --replicas=5
kubectl get deployment web
```

**Observe:**
- The deleted Pod is **not replaced**. Only 2 Pods remain.
- The scale command is accepted (the API server saved it), but **nothing happens**. `READY` stays at 2/5.

**Fix:**

```bash
docker exec techudaan-control-plane mv /tmp/kube-controller-manager.yaml /etc/kubernetes/manifests/
kubectl get pods -l app=web -w
```

**Expected:** within a minute, it catches up and creates all the missing Pods at once. Press `Ctrl+C`, then:

```bash
kubectl scale deployment web --replicas=3
```

**Lesson:** the API server **stores** what you want. The controllers **make it happen**. Without them, Kubernetes is just a database of wishes.

---

## 7. Common Problems

| Symptom | Likely cause |
|---|---|
| Deleted Pods not replaced, scaling does nothing | Controller manager down |
| Deployment stuck, old Pods not removed | New Pods failing; check `kubectl rollout status` |
| Service has no endpoints | Selector doesn't match Pod labels (EndpointSlice controller finds nothing) |
| Namespace stuck in `Terminating` | Some object inside can't be deleted (often a finalizer) |

---

## 8. Interview Questions 🎤

1. What is a controller in Kubernetes?
2. What is reconciliation, or the "desired state" model?
3. Who creates the Pods of a Deployment, the Deployment controller or the ReplicaSet controller?
4. What happens when you delete a Deployment? How do you keep its Pods?
5. If the controller manager is down, what still works and what doesn't?

<details>
<summary>Answers</summary>

1. A loop that watches one type of object and makes the actual state match the desired state.
2. You declare **what** you want; controllers continuously compare it with reality and fix differences.
3. The **ReplicaSet** controller. The Deployment controller creates and manages the ReplicaSets.
4. The garbage collector deletes its ReplicaSets and Pods via `ownerReferences`. Use `--cascade=orphan` to keep them.
5. Running Pods keep running and the API server accepts changes, but nothing is acted on: no self-healing, no scaling, no rollouts, no endpoint updates.

</details>

---

## ✅ Recap

- One process, **many controllers**, each running **observe → compare → act** forever.
- **Deployment → ReplicaSet → Pod**, linked by `ownerReferences`.
- The API server **stores** desired state; controllers **make it real**.

➡️ Next: [05. kubelet, the node agent](05-kubelet.md)
