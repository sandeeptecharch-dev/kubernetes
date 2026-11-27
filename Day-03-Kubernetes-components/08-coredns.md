# 08. CoreDNS: The Phone Book

> Nobody remembers IP addresses. CoreDNS lets your apps call each other **by name**.

⬅️ Previous: [07. kube-proxy](07-kube-proxy.md) | ➡️ Next: [09. CNI plugin](09-cni-plugin.md)

---

## 1. What Is It?

CoreDNS is the **DNS server inside your cluster**. It turns names into IP addresses.

Every Service automatically gets a DNS name:

```
<service-name>.<namespace>.svc.cluster.local
     web     .  default  .svc.cluster.local   →   10.96.45.12
```

So your app can call `http://payment-service` instead of `http://10.96.123.45`, and it keeps working even if the Service is recreated with a new IP.

CoreDNS is an **add-on**: it runs as a normal **Deployment** (usually 2 Pods) in the `kube-system` namespace, behind a Service called `kube-dns`.

---

## 2. Real-Life Analogy 🚆

CoreDNS is the **railway enquiry counter (139)**.

- You don't memorise the platform number of every train. You ask: "Where is the Rajdhani?"
- The enquiry counter looks it up and gives you the current platform.
- If the platform changes tomorrow, you still ask by name, and get the new answer.

---

## 3. How It Works

```
  Pod "frontend" runs:  curl http://payment-service
          │
          │ 1. Reads its /etc/resolv.conf
          │    nameserver 10.96.0.10  (the kube-dns Service)
          ▼
  ┌──────────────────────────┐
  │  CoreDNS (2 Pods)        │  2. Watches Services via the API server
  │  "payment-service.       │     and answers from that list
  │   default.svc.           │
  │   cluster.local?"        │
  └────────────┬─────────────┘
               │ 3. Answer: 10.96.123.45
               ▼
  frontend connects to 10.96.123.45 → kube-proxy rules → a payment Pod
```

### Short names vs full names

| You type | Works from | Why |
|---|---|---|
| `web` | Same namespace only | The Pod's search list adds `default.svc.cluster.local` |
| `web.default` | Any namespace | Names the namespace explicitly |
| `web.default.svc.cluster.local` | Anywhere | The fully qualified name (FQDN) |

---

## 4. Key Facts to Remember

| Fact | Why it matters |
|---|---|
| Runs as a **Deployment** (usually 2 Pods) | 2 copies, so DNS survives one Pod failing |
| Its Service is named **`kube-dns`** (for historical reasons) | Its IP is usually `10.96.0.10` |
| The kubelet writes every Pod's `/etc/resolv.conf` | That's how Pods know where DNS is |
| Config lives in the **`coredns` ConfigMap** (the `Corefile`) | Where you change DNS behaviour |
| Works by IP but not by name → **DNS problem** | The fastest way to narrow down network issues |

---

## 5. Practical 🧪

**Setup:**

```bash
kubectl create deployment web --image=nginx --replicas=3 2>/dev/null || true
kubectl expose deployment web --port=80 2>/dev/null || true
```

### Step 1: Find CoreDNS

```bash
kubectl -n kube-system get deployment coredns
kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
kubectl -n kube-system get svc kube-dns
```

**Expected:** a Deployment with 2/2 ready, 2 Pods, and a Service `kube-dns` with an IP like `10.96.0.10`.

**What this proves:** CoreDNS is just an app running on the cluster, like yours, behind its own Service.

### Step 2: Read its configuration (the Corefile)

```bash
kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}'
```

**Expected:** a block including `kubernetes cluster.local in-addr.arpa ip6.arpa`, `forward . /etc/resolv.conf` and `cache 30`.

**What this proves:**
- `kubernetes cluster.local`: answer names for Services in the cluster
- `forward .`: send everything else (like `google.com`) to an upstream DNS server
- `cache 30`: remember answers for 30 seconds

### Step 3: Look inside a Pod's DNS settings

```bash
kubectl run dnstest --image=busybox:1.36 --restart=Never -- sleep 3600
kubectl wait --for=condition=Ready pod/dnstest --timeout=60s
kubectl exec dnstest -- cat /etc/resolv.conf
```

**Expected (something like):**

```
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
```

**What this proves:**
- `nameserver`: every Pod is pointed at CoreDNS automatically
- `search`: why the short name `web` works; it's tried as `web.default.svc.cluster.local` first

### Step 4: Resolve names in different ways

```bash
kubectl exec dnstest -- nslookup web
kubectl exec dnstest -- nslookup web.default
kubectl exec dnstest -- nslookup web.default.svc.cluster.local
kubectl get svc web -o jsonpath='{.spec.clusterIP}{"\n"}'
```

**Expected:** all three return the **same IP**, matching the Service's ClusterIP.

```bash
kubectl exec dnstest -- wget -qO- web | head -4
kubectl exec dnstest -- nslookup kubernetes.io
```

**Expected:** the nginx page by name, and a public IP for `kubernetes.io` (forwarded upstream).

### Step 5: Cross-namespace names

```bash
kubectl create namespace shop
kubectl run shopper -n shop --image=busybox:1.36 --restart=Never -- sleep 3600
kubectl wait -n shop --for=condition=Ready pod/shopper --timeout=60s

kubectl exec -n shop shopper -- nslookup web
kubectl exec -n shop shopper -- nslookup web.default
```

**Expected:** `web` **fails** (`NXDOMAIN`) from the `shop` namespace, while `web.default` **works**.

**What this proves:** short names only work inside the same namespace. Across namespaces, always include the namespace.

### Step 6: Watch CoreDNS answer (logs)

Turn on query logging by adding the `log` plugin:

```bash
kubectl -n kube-system get configmap coredns -o yaml > /tmp/coredns-backup.yaml
kubectl -n kube-system get configmap coredns -o yaml \
  | sed 's/^\( *\)errors$/\1log\n\1errors/' \
  | kubectl apply -f -
```

Wait about 30 seconds for it to reload, then:

```bash
kubectl exec dnstest -- nslookup web > /dev/null
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=10 | grep "web"
```

**Expected:** log lines showing the queries, such as `"A IN web.default.svc.cluster.local. udp ..."`.

Restore the original config:

```bash
kubectl apply -f /tmp/coredns-backup.yaml
```

**What this proves:** you can see every DNS question your apps ask, which is very useful when debugging.

### Clean up

```bash
kubectl delete pod dnstest
kubectl delete namespace shop
```

---

## 6. Break It and Fix It 💥

> ⚠️ Lab cluster only.

**Break:** turn DNS off.

```bash
kubectl -n kube-system scale deployment coredns --replicas=0
kubectl run client --image=busybox:1.36 --rm -it --restart=Never -- wget -T 5 -qO- web
```

**Observe:** the call fails with a "bad address" or timeout error. Is the app broken? Test by IP:

```bash
SVC_IP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}')
kubectl run client --image=busybox:1.36 --rm -it --restart=Never -- wget -T 5 -qO- $SVC_IP | head -4
```

**By IP it works. By name it fails.** That points straight at DNS.

**Fix:**

```bash
kubectl -n kube-system scale deployment coredns --replicas=2
kubectl -n kube-system rollout status deployment coredns
kubectl run client --image=busybox:1.36 --rm -it --restart=Never -- wget -T 5 -qO- web | head -4
```

**Lesson:** always test **by name and by IP**. If IP works and name doesn't, it's DNS. Simple, and it saves hours.

---

## 7. Common Errors

| Symptom | Likely cause | First check |
|---|---|---|
| `could not resolve host` / `bad address` | CoreDNS down, or wrong name | CoreDNS Pods; then try by IP |
| `NXDOMAIN` | Name doesn't exist: wrong namespace or typo | Use `<svc>.<namespace>`; check `kubectl get svc -A` |
| Internal names work, external don't | Upstream forwarding broken | `forward` line in the Corefile; node's DNS |
| Slow DNS lookups | Many search-list attempts (`ndots:5`) | Use fully qualified names ending with a dot |

---

## 8. Interview Questions 🎤

1. What is the full DNS name of a Service called `api` in namespace `prod`?
2. Why does `curl web` work from one namespace but not another?
3. How does a Pod know which DNS server to use?
4. An app can reach another by IP but not by name. What do you check?
5. Where is CoreDNS configured?

<details>
<summary>Answers</summary>

1. `api.prod.svc.cluster.local`
2. Short names are expanded using the Pod's own namespace (the `search` list in `/etc/resolv.conf`). From another namespace you need `web.<namespace>`.
3. The kubelet writes `/etc/resolv.conf` in every Pod, pointing to the `kube-dns` Service IP.
4. CoreDNS: are its Pods running, is the name and namespace correct, and do its logs show errors?
5. In the `coredns` ConfigMap in `kube-system` (the `Corefile`).

</details>

---

## ✅ Recap

- CoreDNS gives every Service a name: `<service>.<namespace>.svc.cluster.local`.
- Pods find it through `/etc/resolv.conf`; short names only work in the same namespace.
- Works by IP but not by name → **DNS**.

➡️ Next: [09. CNI plugin, the road network](09-cni-plugin.md)
