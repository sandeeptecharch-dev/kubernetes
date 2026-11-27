# Module 3 Lab: Watch Every Component Do Its Job

⏱️ **Time:** about 60 minutes
🎯 **Goal:** run one command per component that proves how it works.
💰 **Cost:** free

---

## Setup

Use the same cluster from Module 1. If you deleted it:

```bash
kind create cluster --name techudaan --config ../module-01-architecture/kind-3node.yaml
```

Create a test app for this lab:

```bash
kubectl create deployment web --image=nginx --replicas=3
kubectl expose deployment web --port=80
kubectl get pods,svc -o wide
```

---

## Step 1: kube-apiserver, Every Command Is an HTTP Request

See the real HTTP request behind `kubectl`:

```bash
kubectl get pods -v=6
```

✅ Look for a line like `GET https://127.0.0.1:xxxxx/api/v1/namespaces/default/pods 200 OK`.

Call the API yourself, without `kubectl get`:

```bash
kubectl proxy --port=8001 &
curl -s localhost:8001/api/v1/namespaces/default/pods | grep '"name"' | head
kill %1
```

Check the API server's health checks:

```bash
kubectl get --raw='/readyz?verbose'
```

✍️ **Write down:** how many different resource types does your API server support? (Hint: `kubectl api-resources | wc -l`)

---

## Step 2: etcd, See Where Kubernetes Keeps Everything

Save this helper so you don't retype the certificates:

```bash
ETCD="kubectl -n kube-system exec etcd-techudaan-control-plane -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key"
```

List every key for your Deployment and Pods:

```bash
$ETCD get /registry/deployments/default --prefix --keys-only
$ETCD get /registry/pods/default --prefix --keys-only
```

Now the scary part. Create a Secret and read it straight from etcd:

```bash
kubectl create secret generic db-password --from-literal=password=TechUdaan@123
$ETCD get /registry/secrets/default/db-password
```

✅ Look closely: you can read `TechUdaan@123` in plain text in the output.

✍️ **Write down:** why must production clusters enable encryption at rest for Secrets?

---

## Step 3: kube-scheduler, Filter and Score

**3a. Why don't app Pods land on the control plane?**

```bash
kubectl describe node techudaan-control-plane | grep -i taints
```

✅ You'll see a `NoSchedule` taint. Your Pods don't tolerate it, so the scheduler filters this node out.

**3b. Send a Pod to a specific node.** Label a node, then ask for it:

```bash
kubectl label node techudaan-worker2 disk=ssd
kubectl run fast-app --image=nginx --overrides='{"spec":{"nodeSelector":{"disk":"ssd"}}}'
kubectl get pod fast-app -o wide
```

✅ `fast-app` runs on `techudaan-worker2`, every time.

**3c. Ask for too much.**

```bash
kubectl run greedy --image=nginx --overrides='{"spec":{"containers":[{"name":"greedy","image":"nginx","resources":{"requests":{"cpu":"100"}}}]}}'
kubectl get pod greedy
kubectl describe pod greedy | tail -5
```

✅ `Pending`, with an event like `0/3 nodes are available: ... Insufficient cpu`. This is the **filter** phase in action.

```bash
kubectl delete pod greedy fast-app
```

---

## Step 4: kube-controller-manager, the Family Tree

See the chain Deployment → ReplicaSet → Pod:

```bash
kubectl get deploy,rs,pods -l app=web
POD=$(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}')
kubectl get pod $POD -o jsonpath='{.metadata.ownerReferences[0].kind}{"\n"}'
```

✅ Prints `ReplicaSet`. The Pod knows its parent.

Watch the ReplicaSet controller react to a scale change:

```bash
kubectl scale deployment web --replicas=5
kubectl get pods -l app=web
kubectl scale deployment web --replicas=3
```

Watch the EndpointSlice controller track Pod IPs behind the Service:

```bash
kubectl get endpointslices -l kubernetes.io/service-name=web
```

✅ The listed IPs match the `web` Pod IPs from `kubectl get pods -o wide`.

---

## Step 5: kubelet, the Node Agent

**5a. See its config and its heartbeat:**

```bash
docker exec techudaan-worker grep -E "staticPodPath|cgroupDriver" /var/lib/kubelet/config.yaml
kubectl get leases -n kube-node-lease
```

✅ One Lease per node. The kubelet renews it every few seconds as a heartbeat.

**5b. Create your own static Pod.** Put a file straight into the kubelet's folder, with no API server involved:

```bash
docker exec techudaan-worker sh -c 'cat > /etc/kubernetes/manifests/static-web.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: static-web
spec:
  containers:
    - name: nginx
      image: nginx
EOF'
```

Wait about 20 seconds:

```bash
kubectl get pods -o wide | grep static
```

✅ A Pod named `static-web-techudaan-worker` appears. That's the **mirror Pod**.

Now try to delete it:

```bash
kubectl delete pod static-web-techudaan-worker
kubectl get pods | grep static
```

✅ It comes back. Only removing the file stops it:

```bash
docker exec techudaan-worker rm /etc/kubernetes/manifests/static-web.yaml
```

---

## Step 6: Container Runtime, Look Under the Hood

```bash
docker exec techudaan-worker crictl pods
docker exec techudaan-worker crictl ps
docker exec techudaan-worker crictl images | grep -E "nginx|pause"
```

✅ `crictl pods` lists Pod sandboxes. Find the **pause** image: one tiny pause container per Pod holds its network.

✍️ **Write down:** the number of Pods in `crictl pods` on this node. Does it match `kubectl get pods -A -o wide | grep techudaan-worker | wc -l`?

---

## Step 7: kube-proxy, Rules, Not a Server

```bash
kubectl get svc web
kubectl -n kube-system get configmap kube-proxy -o yaml | grep "mode:"
```

If the mode is empty or `iptables`, see the rules kube-proxy wrote for your Service:

```bash
docker exec techudaan-worker iptables -t nat -L KUBE-SERVICES -n | grep web
```

✅ You'll see the Service's ClusterIP. No machine owns this IP; it lives only in these rules.

_(If the mode is `nftables`, use `docker exec techudaan-worker nft list ruleset | grep -A3 web` instead.)_

---

## Step 8: CoreDNS, the Phone Book

```bash
kubectl run dnstest --image=busybox:1.36 --rm -it --restart=Never -- \
  sh -c "cat /etc/resolv.conf; nslookup web.default.svc.cluster.local; wget -qO- web | head -4"
```

✅ You'll see:
- `resolv.conf` pointing to the CoreDNS Service IP
- `web.default.svc.cluster.local` resolving to the `web` Service IP
- the nginx welcome page, fetched by name

---

## Step 9: CNI, the Road Network

Each node gets its own Pod IP range:

```bash
kubectl get nodes -o custom-columns=NODE:.metadata.name,POD_RANGE:.spec.podCIDR
kubectl get pods -l app=web -o wide
```

✅ Each Pod's IP falls inside its node's range.

See the CNI config the kubelet uses:

```bash
docker exec techudaan-worker ls /etc/cni/net.d
```

Prove Pods on different nodes can talk directly, without NAT:

```bash
kubectl get pods -l app=web -o wide   # pick a Pod IP on the OTHER worker
kubectl run nettest --image=busybox:1.36 --rm -it --restart=Never \
  --overrides='{"spec":{"nodeName":"techudaan-worker"}}' -- wget -qO- <pod-ip-on-worker2> | head -4
```

---

## ✅ Lab Complete When...

- [ ] You saw the real HTTP request behind `kubectl`
- [ ] You read a Secret in plain text from etcd and can explain why that matters
- [ ] You made a Pod go `Pending` and read the scheduler's reason
- [ ] You traced a Pod back to its ReplicaSet and Deployment
- [ ] You created a static Pod that `kubectl delete` couldn't remove
- [ ] You found the pause container
- [ ] You found a Service IP in kube-proxy's rules
- [ ] You resolved a Service name through CoreDNS
- [ ] You matched Pod IPs to node Pod ranges

Keep the cluster running for [break-fix.md](break-fix.md).

---

## 🧹 Clean Up

```bash
kubectl delete secret db-password
kubectl label node techudaan-worker2 disk-
```
