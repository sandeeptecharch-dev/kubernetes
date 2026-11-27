# 02. etcd: The Cluster's Memory

> etcd is the single source of truth. If something isn't in etcd, Kubernetes doesn't know it exists.

⬅️ Previous: [01. kube-apiserver](01-kube-apiserver.md) | ➡️ Next: [03. kube-scheduler](03-kube-scheduler.md)

---

## 1. What Is It?

etcd (pronounced "et-see-dee") is a **key-value database**. It stores the **entire state** of your cluster: every Pod, Deployment, Service, Secret, ConfigMap and node.

Every object is saved under a key that looks like a file path:

```
/registry/deployments/default/web
/registry/pods/default/web-7d9f8c-abc12
/registry/secrets/default/db-password
/registry/minions/techudaan-worker       ← nodes (old name: "minions")
```

Only the **API server** reads and writes etcd. No other component touches it.

---

## 2. Real-Life Analogy 🚆

etcd is the **master reservation chart** of Indian Railways.

- Every booking, every train, every platform assignment is recorded in it.
- Clerks (the API server) read and update it. Passengers never touch it.
- Lose the chart without a copy, and nobody knows who is booked on which train. **That's why you back it up.**

---

## 3. How It Works

```
  kube-apiserver
        │ read / write / watch
        ▼
  ┌──────────────────────────────────────────┐
  │   etcd cluster (production: 3 members)   │
  │                                          │
  │   member 1 ◄──── Raft ────► member 2     │
  │   (leader)         ▲                     │
  │                    └───────► member 3    │
  └──────────────────────────────────────────┘
```

- etcd uses the **Raft** consensus algorithm. A write is only accepted when a **majority** of members agree.
- **3 members** survive 1 failure. **5 members** survive 2 failures. That's why you always use an **odd number**.
- etcd supports **watch**: the API server is notified the moment a key changes. That's how changes travel so fast in Kubernetes.

---

## 4. Key Facts to Remember

| Fact | Why it matters |
|---|---|
| Stores **all** cluster state | Lose etcd with no backup = lose the cluster |
| Only the API server talks to it | etcd is never exposed to users or apps |
| **Secrets are base64-encoded, not encrypted**, by default | Anyone who can read etcd can read every password |
| Needs a **fast disk** | Slow etcd = slow API server = slow cluster |
| Runs as a **static Pod** on the control plane (in kubeadm and kind) | Defined in `/etc/kubernetes/manifests/etcd.yaml` |

---

## 5. Practical 🧪

**Setup:**

```bash
kubectl create deployment web --image=nginx --replicas=3 2>/dev/null || true
```

### Step 1: Find etcd and its data folder

```bash
kubectl get pods -n kube-system -l component=etcd -o wide
docker exec techudaan-control-plane cat /etc/kubernetes/manifests/etcd.yaml \
  | grep -E "data-dir|listen-client-urls"
```

**Expected (something like):**

```
    - --data-dir=/var/lib/etcd
    - --listen-client-urls=https://127.0.0.1:2379,https://172.18.0.x:2379
```

**What this proves:** etcd stores its data on the control-plane node's disk in `/var/lib/etcd`, and listens on port **2379**.

### Step 2: Set up `etcdctl`

etcd needs certificates, even inside the cluster. Save a helper so you don't retype them:

```bash
ETCD="kubectl -n kube-system exec etcd-techudaan-control-plane -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key"

$ETCD member list -w table
$ETCD endpoint status -w table
```

**Expected:** one member (kind runs a single etcd), and a status table showing the DB size and which member is the leader.

**What this proves:** your cluster has one etcd member. In production, you'd see 3 or 5.

### Step 3: See every object as a key

```bash
$ETCD get /registry --prefix --keys-only | head -30
$ETCD get /registry/deployments/default --prefix --keys-only
$ETCD get /registry/pods/default --prefix --keys-only
```

**Expected:** your `web` Deployment and its 3 Pods, each as a key.

Count how many objects your "empty" cluster holds:

```bash
$ETCD get /registry --prefix --keys-only | grep -c registry
```

**What this proves:** everything `kubectl get` shows you is stored here, as keys.

### Step 4: Watch etcd change live

Open **two terminals**.

**Terminal 1**, watch Pod keys (re-create the `ETCD` variable here first):

```bash
$ETCD watch /registry/pods/default --prefix | grep -a --line-buffered "^/registry"
```

**Terminal 2**, make a change:

```bash
kubectl scale deployment web --replicas=5
```

**Expected:** Terminal 1 prints new keys as the Pods are created. Press `Ctrl+C` when done, then scale back:

```bash
kubectl scale deployment web --replicas=3
```

**What this proves:** etcd's watch feature is how changes spread through Kubernetes in real time.

### Step 5: The Secret is not secret 😳

```bash
kubectl create secret generic db-password --from-literal=password=TechUdaan@123
kubectl get secret db-password -o jsonpath='{.data.password}{"\n"}'
```

That looks scrambled, but it's only base64:

```bash
kubectl get secret db-password -o jsonpath='{.data.password}' | base64 -d; echo
```

Now read it straight from etcd:

```bash
$ETCD get /registry/secrets/default/db-password
```

**Expected:** among the output you can read `TechUdaan@123` in plain text.

**What this proves:** by default, Secrets are **stored unencrypted** in etcd. Production clusters must turn on **encryption at rest** and lock down etcd access.

### Step 6: Take a backup

```bash
$ETCD snapshot save /var/lib/etcd/backup.db
docker exec techudaan-control-plane ls -lh /var/lib/etcd/backup.db
```

**Expected:** `Snapshot saved at /var/lib/etcd/backup.db`, and a file a few MB in size.

**What this proves:** one command backs up the entire cluster state. In real jobs, this runs on a schedule and the file is copied off the machine.

---

## 6. Break It and Fix It 💥

> ⚠️ Lab cluster only. **Never** edit etcd directly in a real cluster.

**Break:** delete a Pod directly from etcd, bypassing all the API server's checks.

```bash
POD=$(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}')
echo "Deleting $POD directly from etcd"
$ETCD del /registry/pods/default/$POD
kubectl get pods -l app=web
```

**Observe:**
- The Pod instantly disappears from `kubectl get pods`. Kubernetes reads from etcd, so it no longer exists.
- Within seconds, a **new** Pod appears. The ReplicaSet controller saw 2 instead of 3 and fixed it.

**Lesson:** etcd is the truth. Whatever etcd says, Kubernetes believes, and controllers act on it. That's why etcd access must be strictly protected.

**Clean up:**

```bash
kubectl delete secret db-password
docker exec techudaan-control-plane rm /var/lib/etcd/backup.db
```

---

## 7. Common Problems

| Symptom | Likely cause | What to do |
|---|---|---|
| `kubectl` is very slow, timeouts | etcd disk too slow | Use SSDs; check `etcdctl endpoint status` |
| `etcdserver: mvcc: database space exceeded` | etcd DB hit its size limit | Compact and defragment etcd |
| Cluster state lost after a disk failure | No etcd backup | Always run scheduled `snapshot save` |
| etcd cluster won't accept writes | Lost majority (e.g. 2 of 3 members down) | Restore members or restore from a snapshot |

---

## 8. Interview Questions 🎤

1. What does etcd store, and which component talks to it?
2. Why does etcd run 3 or 5 members, never 4?
3. Are Kubernetes Secrets encrypted in etcd?
4. How would you back up a Kubernetes cluster?
5. What happens if you lose etcd without a backup?

<details>
<summary>Answers</summary>

1. The whole cluster state: every object. Only the kube-apiserver talks to it.
2. Raft needs a majority. 3 survives 1 failure, and 4 also survives only 1, so the 4th adds cost with no extra safety. 5 survives 2.
3. Not by default. They're base64-encoded. You must enable encryption at rest.
4. Take regular `etcdctl snapshot save` backups (plus keep your YAML in Git).
5. The cluster loses all its knowledge: Deployments, Services, Secrets and so on. You'd have to rebuild it from scratch.

</details>

---

## ✅ Recap

- etcd is a **key-value store** holding **everything**. Only the API server touches it.
- Production uses **3 or 5** members, because a write needs a majority (Raft).
- Secrets are **not encrypted by default**, and **no backup = no recovery**.

➡️ Next: [03. kube-scheduler, the matchmaker](03-kube-scheduler.md)
