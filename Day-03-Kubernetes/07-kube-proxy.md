# 07. kube-proxy: The Traffic Router

> Pods come and go, and their IPs change. kube-proxy makes a **Service** give them one stable address.

⬅️ Previous: [06. Container runtime](06-container-runtime.md) | ➡️ Next: [08. CoreDNS](08-coredns.md)

---

## 1. What Is It?

Pods are temporary. When a Pod is replaced, it gets a **new IP**. So how does one app reliably reach another?

With a **Service**: one stable virtual IP (called a **ClusterIP**) that stays the same while the Pods behind it change.

**kube-proxy** is what makes that virtual IP work. It runs on **every node** and writes **network rules** that say: "Traffic to this Service IP → send it to one of these Pod IPs."

> 💡 Despite its name, kube-proxy usually **doesn't carry traffic**. It only writes the rules. The Linux kernel moves the packets.

---

## 2. Real-Life Analogy 🚆

kube-proxy is the **platform signboards and announcement system**.

- Passengers are told "Rajdhani Express" (the Service name and IP), not which coach or platform.
- The signboards (rules) send each passenger to an available coach (a Pod).
- When a coach is swapped out, the signboards are updated. Passengers never notice.

---

## 3. How It Works

```
   App Pod calls  http://web  →  10.96.45.12:80  (ClusterIP, virtual)
                                       │
                ┌──────────────────────▼──────────────────────┐
                │  Rules on the node (written by kube-proxy)  │
                │  "10.96.45.12:80 → pick one, at random:"    │
                │     1/3 → 10.244.1.5:80                     │
                │     1/2 → 10.244.2.7:80   (of the rest)     │
                │     rest→ 10.244.1.9:80                     │
                └──────────────────────┬──────────────────────┘
                                       ▼
                               chosen Pod receives it
```

**Where does kube-proxy get the Pod IPs?** From **EndpointSlices**, kept up to date by a controller (see [04](04-kube-controller-manager.md)). kube-proxy watches them through the API server and rewrites its rules whenever Pods change.

### Modes

| Mode | How it works | Notes |
|---|---|---|
| **iptables** | Linux iptables rules | Common default |
| **IPVS** | Linux kernel load balancer | Better for very large numbers of Services |
| **nftables** | Newer Linux firewall framework | The modern successor to iptables |

Some CNI plugins, such as **Cilium**, can replace kube-proxy entirely.

### Service types

| Type | Reachable from | Used for |
|---|---|---|
| **ClusterIP** (default) | Inside the cluster only | App-to-app traffic |
| **NodePort** | Any node's IP, on a port 30000–32767 | Simple external access, testing |
| **LoadBalancer** | A cloud load balancer's public IP | Production external access (on cloud) |

---

## 4. Key Facts to Remember

| Fact | Why it matters |
|---|---|
| Runs as a **DaemonSet**: one Pod per node | Every node needs the rules |
| A ClusterIP is **virtual** | No machine has it. You can't find it with `ip addr`; it exists only in rules |
| Doesn't carry traffic itself (iptables/IPVS modes) | The kernel forwards packets directly |
| Uses **EndpointSlices** to know Pod IPs | No endpoints = nowhere to send traffic |
| Service IPs come from `service-cluster-ip-range` | Set on the API server (often `10.96.0.0/12` or `/16`) |

---

## 5. Practical 🧪

**Setup:**

```bash
kubectl create deployment web --image=nginx --replicas=3 2>/dev/null || true
kubectl expose deployment web --port=80 2>/dev/null || true
```

### Step 1: Find kube-proxy

```bash
kubectl -n kube-system get daemonset kube-proxy
kubectl -n kube-system get pods -l k8s-app=kube-proxy -o wide
```

**Expected:** `DESIRED 3`, `READY 3`. One kube-proxy Pod per node.

**What this proves:** a **DaemonSet** makes sure exactly one copy runs on every node.

### Step 2: Which mode is it using?

```bash
kubectl -n kube-system get configmap kube-proxy -o yaml | grep "mode:"
kubectl -n kube-system logs -l k8s-app=kube-proxy --tail=50 | grep -i "proxier\|mode" | head -3
```

**Expected:** `mode: iptables` (or empty, which means the default). Use the iptables commands below. If it says `nftables`, use the nftables alternative shown in Step 4.

### Step 3: The Service and its endpoints

```bash
kubectl get svc web
kubectl get endpointslices -l kubernetes.io/service-name=web
kubectl get pods -l app=web -o wide
```

**Expected:** a ClusterIP such as `10.96.x.x`, and an EndpointSlice listing the **same 3 Pod IPs** you see in the Pod list.

**What this proves:** the Service is a stable front; the EndpointSlice is the live list of Pods behind it.

### Step 4: Find kube-proxy's rules for your Service

```bash
SVC_IP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}')
echo "Service IP: $SVC_IP"
docker exec techudaan-worker iptables -t nat -L KUBE-SERVICES -n | grep "$SVC_IP"
```

**Expected (something like):**

```
KUBE-SVC-XXXXXXXXXXXXXXXX  tcp  --  0.0.0.0/0  10.96.45.12  /* default/web cluster IP */ tcp dpt:80
```

Now follow that chain to see the load balancing:

```bash
CHAIN=$(docker exec techudaan-worker iptables -t nat -L KUBE-SERVICES -n | grep "$SVC_IP" | awk '{print $1}')
docker exec techudaan-worker iptables -t nat -L $CHAIN -n
```

**Expected:** 3 `KUBE-SEP-...` lines (one per Pod), with `statistic mode random probability 0.33333` and `0.50000`.

**What this proves:** load balancing is just probability. Rule 1 takes 1/3 of traffic, rule 2 takes half of what's left, and rule 3 takes the rest. Each Pod gets about 1/3.

_(nftables mode instead: `docker exec techudaan-worker nft list ruleset | grep -B2 -A6 "$SVC_IP"`)_

### Step 5: Watch the rules change when Pods change

```bash
kubectl scale deployment web --replicas=5
sleep 10
docker exec techudaan-worker iptables -t nat -L $CHAIN -n | grep -c KUBE-SEP
kubectl scale deployment web --replicas=3
```

**Expected:** `5`. kube-proxy rewrote the rules automatically.

### Step 6: Prove the ClusterIP is virtual

```bash
docker exec techudaan-worker ip addr | grep -c "$SVC_IP"
kubectl run client --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- $SVC_IP | head -4
```

**Expected:** `0` (no network card has this IP), yet the request still reaches nginx.

**What this proves:** the Service IP exists **only in rules**. Packets are rewritten to a real Pod IP on the way out.

### Step 7: NodePort, reaching the app from outside

```bash
kubectl expose deployment web --type=NodePort --name=web-np --port=80
NODE_PORT=$(kubectl get svc web-np -o jsonpath='{.spec.ports[0].nodePort}')
echo "NodePort: $NODE_PORT"
docker exec techudaan-control-plane curl -s techudaan-worker:$NODE_PORT | head -4
docker exec techudaan-control-plane curl -s techudaan-worker2:$NODE_PORT | head -4
```

**Expected:** the nginx page from **both** workers' IPs, on the same port.

**What this proves:** kube-proxy opens the NodePort on **every** node, so any node can receive traffic and forward it to a Pod, even one on a different node.

```bash
kubectl delete svc web-np
```

---

## 6. Break It and Fix It 💥

> ⚠️ Lab cluster only.

**Break:** change the Service's selector to a label no Pod has (a typo).

```bash
kubectl patch service web -p '{"spec":{"selector":{"app":"webb"}}}'
kubectl run client --image=busybox:1.36 --rm -it --restart=Never -- wget -T 5 -qO- web
```

**Observe:** the request fails, but the Pods are running fine. Investigate:

```bash
kubectl get endpointslices -l kubernetes.io/service-name=web
docker exec techudaan-worker iptables -t nat -L KUBE-SERVICES -n | grep -i "web" | head -3
kubectl describe svc web | grep -i selector
kubectl get pods --show-labels | grep web
```

The EndpointSlice is empty, and kube-proxy has no Pods to send traffic to. The selector says `app=webb`; the Pods say `app=web`.

**Fix:**

```bash
kubectl patch service web -p '{"spec":{"selector":{"app":"web"}}}'
kubectl get endpointslices -l kubernetes.io/service-name=web
kubectl run client --image=busybox:1.36 --rm -it --restart=Never -- wget -T 5 -qO- web | head -4
```

**Lesson:** "Service doesn't work but Pods are fine" → check **endpoints** first. An empty list is almost always a **label/selector mismatch**. This is one of the most common real-world bugs.

---

## 7. Common Errors

| Symptom | Likely cause | First check |
|---|---|---|
| Connection refused / timeout to a Service | No endpoints | `kubectl get endpointslices -l kubernetes.io/service-name=<svc>` |
| Endpoints exist but calls fail | Wrong `targetPort`, or app not listening | Compare `targetPort` with the container's port |
| Service works from some nodes only | kube-proxy broken on one node | kube-proxy Pod and logs on that node |
| Pods not in endpoints though labels match | Pods not **Ready** (readiness probe failing) | `kubectl get pods` → READY column |

---

## 8. Interview Questions 🎤

1. Why do we need Services when Pods already have IPs?
2. What does kube-proxy actually do? Does traffic pass through it?
3. Can you ping a ClusterIP? Why or why not?
4. What's the difference between ClusterIP, NodePort and LoadBalancer?
5. A Service has no endpoints. What do you check?

<details>
<summary>Answers</summary>

1. Pod IPs change whenever Pods are replaced. A Service gives one stable IP and name, and load-balances across the current Pods.
2. It watches Services and EndpointSlices and writes network rules (iptables/IPVS/nftables) on each node. In those modes, traffic doesn't pass through kube-proxy; the kernel forwards it.
3. Usually no. It's a virtual IP that only exists in forwarding rules for specific ports, not a real interface.
4. **ClusterIP:** internal only. **NodePort:** opens a port on every node. **LoadBalancer:** provisions an external (cloud) load balancer.
5. The Service's selector vs the Pods' labels, and whether those Pods are Ready.

</details>

---

## ✅ Recap

- A **Service** gives Pods one stable virtual IP; **kube-proxy** makes it work with rules on every node.
- It learns Pod IPs from **EndpointSlices** and load-balances by probability.
- Service broken, Pods fine → check **endpoints** and **labels** first.

➡️ Next: [08. CoreDNS, the phone book](08-coredns.md)
