# 09. CNI Plugin: The Road Network

> Kubernetes sets the networking rules. The CNI plugin builds the roads that make them true.

⬅️ Previous: [08. CoreDNS](08-coredns.md) | 🏠 Back to [all components](../notes.md)

---

## 1. What Is It?

Kubernetes has strict networking rules, but **doesn't implement them itself**. A **CNI plugin** (Container Network Interface) does.

When a Pod is created, the kubelet calls the CNI plugin, which:

1. Gives the Pod its **own IP address**
2. Connects the Pod to the node's network (with a virtual cable called a **veth pair**)
3. Makes sure Pods on **different nodes** can reach each other

### The 3 Kubernetes networking rules every CNI must follow

1. **Every Pod gets its own IP address.**
2. **Every Pod can reach every other Pod directly, without NAT**, even across nodes.
3. **What a Pod sees as its own IP is the same IP others use to reach it.**

### Popular CNI plugins

| Plugin | Known for |
|---|---|
| **Calico** | Network policies, widely used in production |
| **Cilium** | eBPF-based, high performance, can replace kube-proxy |
| **Flannel** | Very simple, good for learning |
| **kindnet** | The simple default in kind (what your lab uses) |

---

## 2. Real-Life Analogy 🚆

The CNI plugin is the **railway tracks and track-laying team**.

- Every new train (Pod) gets its own **track number** (IP address).
- Tracks connect **every station** (node), so a train at one station can reach any other station directly.
- Kubernetes says "every train must be reachable". The track team decides **how** to lay the tracks.

---

## 3. How It Works

```
 ┌────────── Node: techudaan-worker ──────────┐     ┌────────── Node: techudaan-worker2 ─────────┐
 │  podCIDR: 10.244.1.0/24                    │     │  podCIDR: 10.244.2.0/24                    │
 │                                            │     │                                            │
 │  [Pod A 10.244.1.5]   [Pod B 10.244.1.9]   │     │  [Pod C 10.244.2.7]                        │
 │        │ veth              │ veth          │     │        │ veth                              │
 │        └──────┬────────────┘               │     │        │                                   │
 │          node network                      │     │   node network                             │
 │  route: 10.244.2.0/24 → worker2's IP  ─────┼─────┼──►                                         │
 └────────────────────────────────────────────┘     └────────────────────────────────────────────┘

   Pod A → Pod C: the packet leaves with source 10.244.1.5 and arrives with source 10.244.1.5 (no NAT)
```

- Each node gets its own Pod IP range (**podCIDR**). Pod IPs on that node come from that range.
- The CNI plugin adds **routes** so each node knows: "Pods in range X live on node Y."

---

## 4. Key Facts to Remember

| Fact | Why it matters |
|---|---|
| Kubernetes **requires** a CNI plugin | Without one, nodes stay `NotReady` and Pods can't start |
| Config lives in **`/etc/cni/net.d/`** on each node | The kubelet reads it to know which plugin to call |
| Plugin programs live in **`/opt/cni/bin/`** | The actual executables the kubelet runs |
| Each node has a **podCIDR** | Tells you which node a Pod IP belongs to |
| **No NAT** between Pods | The receiver sees the real sender IP |
| **Network policies** (firewall rules for Pods) need a CNI that supports them | Calico and Cilium do; simple ones may not |

---

## 5. Practical 🧪

**Setup:**

```bash
kubectl create deployment web --image=nginx --replicas=4 2>/dev/null || kubectl scale deployment web --replicas=4
sleep 10
```

### Step 1: Find the CNI plugin

```bash
kubectl -n kube-system get daemonset
kubectl -n kube-system get pods -l app=kindnet -o wide
```

**Expected:** a `kindnet` DaemonSet with one Pod per node.

**What this proves:** like kube-proxy, the CNI plugin runs on **every** node as a DaemonSet.

### Step 2: Look at the CNI files on a node

```bash
docker exec techudaan-worker ls /etc/cni/net.d/
docker exec techudaan-worker sh -c 'cat /etc/cni/net.d/*'
docker exec techudaan-worker ls /opt/cni/bin/
```

**Expected:** a config file (such as `10-kindnet.conflist`) naming the plugins and the Pod subnet, and plugin programs such as `bridge`, `host-local`, `loopback` and `ptp`.

**What this proves:** when the kubelet creates a Pod, it reads this config and runs these programs to set up the Pod's network.

### Step 3: Each node has its own Pod IP range

```bash
kubectl get nodes -o custom-columns=NODE:.metadata.name,POD_RANGE:.spec.podCIDR
kubectl get pods -l app=web -o wide
```

**Expected (something like):**

```
NODE                      POD_RANGE
techudaan-control-plane   10.244.0.0/24
techudaan-worker          10.244.1.0/24
techudaan-worker2         10.244.2.0/24
```

And Pods on `techudaan-worker` have IPs like `10.244.1.x`.

**What this proves:** just by looking at a Pod IP, you can tell which node it's on.

### Step 4: See the routes between nodes

```bash
docker exec techudaan-worker ip route
kubectl get nodes -o wide
```

**Expected (something like):**

```
10.244.0.0/24 via 172.18.0.2 dev eth0     ← control plane's Pods
10.244.2.0/24 via 172.18.0.4 dev eth0     ← worker2's Pods
```

Match the `via` IPs to the nodes' `INTERNAL-IP` column.

**What this proves:** this is the "road map". Traffic for another node's Pods is sent straight to that node.

### Step 5: See the virtual cables (veth)

```bash
docker exec techudaan-worker ip link | grep -c veth
kubectl get pods -A -o wide --field-selector spec.nodeName=techudaan-worker --no-headers | grep -vc " 172.18."
```

**Expected:** the two numbers are equal or close: one `veth` per Pod that has its own Pod IP on this node.

**What this proves:** each Pod is plugged into the node with its own virtual network cable. (Pods using the node's IP, such as kube-proxy, don't need one.)

### Step 6: Pod-to-Pod across nodes, with no NAT

Pick a `web` Pod on **worker2** and note its IP and name:

```bash
kubectl get pods -l app=web -o wide | grep worker2
TARGET_POD=$(kubectl get pods -l app=web -o wide --no-headers | grep worker2 | head -1 | awk '{print $1}')
TARGET_IP=$(kubectl get pod $TARGET_POD -o jsonpath='{.status.podIP}')
echo "Target: $TARGET_POD at $TARGET_IP"
```

Run a client Pod pinned to **worker** (the other node) and call the target directly by IP:

```bash
kubectl run nettest --image=busybox:1.36 --restart=Never \
  --overrides='{"spec":{"nodeName":"techudaan-worker"}}' -- sleep 3600
kubectl wait --for=condition=Ready pod/nettest --timeout=60s
kubectl get pod nettest -o wide
kubectl exec nettest -- wget -qO- $TARGET_IP | head -4
```

Now check **who nginx says called it**:

```bash
kubectl logs $TARGET_POD --tail=1
```

**Expected:** the log line starts with **nettest's own Pod IP** (`10.244.1.x`), not a node IP.

**What this proves:** the packet crossed from one node to another and arrived with the **real sender IP**. No NAT, exactly as Kubernetes' rule 2 requires.

### Clean up

```bash
kubectl delete pod nettest
kubectl scale deployment web --replicas=3
```

---

## 6. Experiment: A Cluster With No CNI 💥

> This creates a **separate, temporary** cluster, so your main lab cluster is untouched.

Save as `/tmp/no-cni.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
nodes:
  - role: control-plane
```

```bash
kind create cluster --name nocni --config /tmp/no-cni.yaml
kubectl --context kind-nocni get nodes
kubectl --context kind-nocni -n kube-system get pods
kubectl --context kind-nocni describe node nocni-control-plane | grep -i "ready\|network" | head -5
```

**Observe:**
- The node is **`NotReady`**
- **CoreDNS Pods are stuck in `Pending`**
- The node conditions mention the network plugin is not ready (`cni plugin not initialized` or similar)

**Lesson:** without a CNI plugin, Kubernetes can't give Pods an IP, so nothing can run. Installing a CNI (Calico, Cilium, Flannel) is one of the first steps on any real cluster.

**Clean up** and switch back to your main cluster:

```bash
kind delete cluster --name nocni
kubectl config use-context kind-techudaan
kubectl get nodes
```

---

## 7. Common Errors

| Symptom | Likely cause | First check |
|---|---|---|
| Node `NotReady`, "network plugin not ready" | No CNI installed, or it's crashing | CNI DaemonSet Pods in `kube-system` |
| Pods stuck in `ContainerCreating` | CNI failed to set up the Pod network | `kubectl describe pod` → Events (`failed to setup network`) |
| Pods on different nodes can't talk | Routes or firewall between nodes | `ip route` on nodes; cloud firewall rules |
| Pods can't reach anything | A NetworkPolicy is blocking traffic | `kubectl get networkpolicy -A` |

---

## 8. Interview Questions 🎤

1. What is CNI, and why does Kubernetes need a plugin for networking?
2. What are the Kubernetes networking rules a CNI must follow?
3. How can you tell which node a Pod IP belongs to?
4. A new cluster's nodes are all `NotReady`. What's the most likely cause?
5. Name two CNI plugins and something each is known for.

<details>
<summary>Answers</summary>

1. The Container Network Interface: a standard for plugins that give Pods IPs and connect them. Kubernetes defines the rules but leaves the implementation to plugins.
2. Every Pod gets its own IP; every Pod can reach every other Pod without NAT; a Pod sees the same IP others use to reach it.
3. Compare it with each node's `podCIDR` (`kubectl get nodes -o custom-columns=NODE:.metadata.name,CIDR:.spec.podCIDR`).
4. No CNI plugin installed yet.
5. For example, **Calico** for network policies; **Cilium** for eBPF performance and kube-proxy replacement; **Flannel** for simplicity.

</details>

---

## ✅ Recap

- The CNI plugin gives every Pod an **IP** and connects Pods **across nodes**.
- Each node has a **podCIDR**; routes send traffic to the right node, with **no NAT**.
- No CNI = nodes `NotReady` and nothing can run.

---

## 🎉 You've Finished All 9 Components!

| # | Component | One line |
|---|---|---|
| 01 | [kube-apiserver](01-kube-apiserver.md) | The only door into the cluster |
| 02 | [etcd](02-etcd.md) | Stores everything |
| 03 | [kube-scheduler](03-kube-scheduler.md) | Decides where Pods run |
| 04 | [kube-controller-manager](04-kube-controller-manager.md) | Keeps reality matching the plan |
| 05 | [kubelet](05-kubelet.md) | Makes Pods actually run |
| 06 | [Container runtime](06-container-runtime.md) | Pulls images, starts containers |
| 07 | [kube-proxy](07-kube-proxy.md) | Makes Services reachable |
| 08 | [CoreDNS](08-coredns.md) | Turns names into IPs |
| 09 | [CNI plugin](09-cni-plugin.md) | Connects all Pods |

➡️ Now test yourself: [break-fix.md](../break-fix.md) → [quiz.md](../quiz.md)
