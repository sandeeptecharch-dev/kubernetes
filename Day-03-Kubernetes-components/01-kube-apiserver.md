# 01. kube-apiserver: The Front Door

> Every request to the cluster, from you or from any component, goes through the API server. Nothing else is allowed to touch the cluster directly.

⬅️ [All components](../notes.md) | ➡️ Next: [02. etcd](02-etcd.md)

---

## 1. What Is It?

The kube-apiserver is a **web server with a REST API**. When you type `kubectl get pods`, kubectl doesn't do anything magical. It sends an **HTTPS request** to the API server, and the API server sends back JSON.

It is the **centre of the cluster**:

- **You** talk to it (through `kubectl`)
- The **scheduler, controllers and kubelets** talk to it
- It is the **only** component that reads and writes **etcd**

If you understand the API server, you understand how every other component communicates.

---

## 2. Real-Life Analogy 🚆

The API server is the **railway reservation counter**.

- You can't walk into the control room and change the chart yourself. You go to the counter.
- The clerk checks your **ID** (authentication), checks whether you're **allowed** to book (authorization), and checks the **form is filled correctly** (admission).
- Only then is your booking written into the master chart (etcd).

---

## 3. How It Works

Every request passes **3 gates** before it is saved:

```
  kubectl / kubelet / controller
              │  HTTPS request
              ▼
  ┌──────────────────────────────────────────────────────────┐
  │                    kube-apiserver                        │
  │                                                          │
  │  1. AUTHENTICATION ──► 2. AUTHORIZATION ──► 3. ADMISSION │
  │     "Who are you?"       "Are you allowed?"   "Is it     │
  │     certificate,         RBAC rules            valid?    │
  │     token                                      Add       │
  │                                                defaults?"│
  └──────────────────────────────┬───────────────────────────┘
                                 │  saved
                                 ▼
                               etcd
```

Then other components find out about the change through a **watch**: a long-lived connection where the API server pushes updates ("a new Pod was created") instead of components asking again and again.

---

## 4. Key Facts to Remember

| Fact | Why it matters |
|---|---|
| It's the **only** component that talks to etcd | All security checks happen in one place |
| It is **stateless** | Production runs 2 to 3 copies behind a load balancer for high availability |
| Every `kubectl` command is an HTTP call | You can call the API with `curl` too |
| It runs as a **static Pod** on the control plane | Its definition lives in `/etc/kubernetes/manifests/kube-apiserver.yaml` |
| If it goes down, **running apps keep running** | But nobody can change anything, and self-healing stops |

---

## 5. Practical 🧪

**Setup:** you need the cluster from [Module 1](../../module-01-architecture/lab.md). Then:

```bash
kubectl create deployment web --image=nginx --replicas=3 2>/dev/null || true
```

### Step 1: Find the API server

```bash
kubectl get pods -n kube-system -l component=kube-apiserver -o wide
```

**Expected:** one Pod named `kube-apiserver-techudaan-control-plane`, running on the control-plane node.

**What this proves:** the API server is just a Pod on the control-plane node.

### Step 2: Read its configuration

```bash
docker exec techudaan-control-plane cat /etc/kubernetes/manifests/kube-apiserver.yaml \
  | grep -E "etcd-servers|secure-port|authorization-mode|service-cluster-ip-range"
```

**Expected (something like):**

```
    - --authorization-mode=Node,RBAC
    - --etcd-servers=https://127.0.0.1:2379
    - --secure-port=6443
    - --service-cluster-ip-range=10.96.0.0/16
```

**What this proves:**
- `etcd-servers`: the API server is the one that connects to etcd
- `authorization-mode=Node,RBAC`: gate 2 uses RBAC
- `secure-port=6443`: the standard Kubernetes API port
- `service-cluster-ip-range`: where Service IPs come from (you'll see this again with kube-proxy)

### Step 3: See the HTTP request behind kubectl

```bash
kubectl get pods -v=6
```

**Expected:** a line like:

```
GET https://127.0.0.1:xxxxx/api/v1/namespaces/default/pods?limit=500 200 OK in 12 milliseconds
```

Try `-v=8` to also see the JSON response.

**What this proves:** `kubectl` is just an HTTP client.

### Step 4: Talk to the API without kubectl

Open a local, already-authenticated tunnel to the API server:

```bash
kubectl proxy --port=8001 &
```

**Read** (GET) your Pods with curl:

```bash
curl -s localhost:8001/api/v1/namespaces/default/pods | grep '"name": "web'
```

**Create** (POST) a Pod with curl, no kubectl involved:

```bash
curl -s -X POST localhost:8001/api/v1/namespaces/default/pods \
  -H "Content-Type: application/json" \
  -d '{"apiVersion":"v1","kind":"Pod","metadata":{"name":"curl-pod"},"spec":{"containers":[{"name":"nginx","image":"nginx"}]}}' \
  | grep '"phase"'
kubectl get pod curl-pod
```

**Expected:** `"phase": "Pending"` from curl, and a few seconds later `curl-pod` is `Running`.

Stop the proxy and clean up:

```bash
kill %1
kubectl delete pod curl-pod
```

**What this proves:** anything that can send HTTP can control Kubernetes. Tools like Argo CD, Helm and CI/CD pipelines all work this way.

### Step 5: Test gate 2 (authorization)

Ask the API server what you're allowed to do:

```bash
kubectl auth can-i create pods
kubectl auth can-i create pods --as=system:serviceaccount:default:default
```

**Expected:** `yes` for you (you're the cluster admin), `no` for the default service account.

Now act as that service account:

```bash
kubectl get pods --as=system:serviceaccount:default:default
```

**Expected:**

```
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:default:default" cannot list resource "pods" ...
```

**What this proves:** the request reached the API server and passed authentication, but RBAC (gate 2) blocked it.

### Step 6: Test gate 3 (admission)

Try to create a Pod in a namespace that doesn't exist:

```bash
kubectl run ghost-pod --image=nginx -n ghost
```

**Expected:**

```
Error from server (NotFound): namespaces "ghost" not found
```

**What this proves:** an admission check rejected the request before anything was saved.

### Step 7: Check its health and what it knows

```bash
kubectl get --raw='/readyz?verbose' | tail -5
kubectl api-resources | head -15
kubectl api-resources | wc -l
kubectl explain pod.spec.containers.image
```

**What this proves:** the API server exposes health checks, a list of every resource type it supports, and built-in documentation (`kubectl explain`).

---

## 6. Break It and Fix It 💥

> ⚠️ Lab cluster only.

**Break:** move its static Pod file away. The kubelet stops the API server.

```bash
docker exec techudaan-control-plane mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
sleep 30
kubectl get pods
```

**Observe:** `The connection to the server 127.0.0.1:xxxxx was refused`. But check a worker directly:

```bash
docker exec techudaan-worker crictl ps | grep nginx
```

Your nginx containers are still running.

**Fix:**

```bash
docker exec techudaan-control-plane mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
sleep 45
kubectl get nodes
```

**Lesson:** API server down = you can't manage anything. It does **not** mean your users see an outage.

---

## 7. Common Errors

| Error message | Meaning | First check |
|---|---|---|
| `connection ... refused` | API server down or wrong address | Is the control plane up? Correct kubeconfig? |
| `Unauthorized` (401) | Gate 1 failed: bad or expired credentials | Your kubeconfig certificate or token |
| `Forbidden` (403) | Gate 2 failed: RBAC doesn't allow this | `kubectl auth can-i <verb> <resource>` |
| `admission webhook ... denied` | Gate 3 failed: a policy rejected it | Read the message; it names the rule |

---

## 8. Interview Questions 🎤

1. What happens inside the API server when you run `kubectl apply`?
2. Why is the API server the only component allowed to talk to etcd?
3. If the API server goes down, do running applications stop?
4. What is the difference between authentication and authorization?
5. How do other components learn about changes without constantly polling?

<details>
<summary>Answers</summary>

1. The request goes through authentication → authorization (RBAC) → admission (validation and defaults), then the object is saved in etcd, and watchers are notified.
2. It centralises security, validation and consistency. Every change goes through the same checks, and etcd is never exposed directly.
3. No. Containers keep running on the nodes. You lose the ability to make changes, scheduling and self-healing.
4. Authentication answers "who are you?" (certificates, tokens). Authorization answers "what are you allowed to do?" (RBAC rules).
5. Through **watches**: long-lived connections where the API server streams changes to them.

</details>

---

## ✅ Recap

- The API server is the **only door** into the cluster, and the only component that talks to etcd.
- Every request passes **authentication → authorization → admission**.
- `kubectl` is just an HTTP client; `curl` can do the same job.

➡️ Next: [02. etcd, the cluster's memory](02-etcd.md)
