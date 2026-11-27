# 05. kubelet: The Node Agent

> The kubelet is the only component that makes Pods **actually run**. Everything else just decides and records.

⬅️ Previous: [04. kube-controller-manager](04-kube-controller-manager.md) | ➡️ Next: [06. Container runtime](06-container-runtime.md)

---

## 1. What Is It?

The kubelet is an **agent that runs on every node**. It's not a Pod; it's a normal **system service** (managed by `systemd`).

Its jobs:

1. **Watch** the API server for Pods assigned to its node
2. **Ask the container runtime** to pull images and start containers
3. **Run health checks** (probes) and restart unhealthy containers
4. **Report** Pod and node status back to the API server
5. Send a **heartbeat** so the control plane knows the node is alive
6. Run **static Pods** straight from files, even with no API server

---

## 2. Real-Life Analogy 🚆

The kubelet is the **station master**.

- The control room (API server) says, "Train 12951 is assigned to your station."
- The station master tells the **engine driver** (container runtime) to start it.
- They keep checking the train is fine, and call in every few seconds: "Station OK."
- If the station master stops calling in, the control room assumes the station is down and reroutes its trains.

---

## 3. How It Works

```
             kube-apiserver
              ▲          │ "Pod X is assigned to techudaan-worker"
   status +   │          ▼
   heartbeat  │   ┌────────────────────────────────────┐
              └───┤  kubelet  (system service)         │
                  │                                    │
                  │  • watches Pods for its node       │
                  │  • runs liveness/readiness probes  │
                  │  • reads /etc/kubernetes/manifests │ ◄── static Pods
                  └───────────────┬────────────────────┘
                                  │ CRI (gRPC)
                                  ▼
                        containerd (runtime)
                                  │
                                  ▼
                           [containers]
```

---

## 4. Key Facts to Remember

| Fact | Why it matters |
|---|---|
| A **system service**, not a Pod | Check it with `systemctl` and `journalctl`, not `kubectl logs` |
| Config file: `/var/lib/kubelet/config.yaml` | Where static Pod path, cgroup driver and limits are set |
| Sends heartbeats via **Lease** objects | Missing heartbeats → node `NotReady` |
| Runs **probes** | Liveness fails → container restarted; readiness fails → removed from Service traffic |
| Runs **static Pods** from `/etc/kubernetes/manifests` | That's how the control plane itself starts |
| Static Pods show as **mirror Pods** | Named `<pod>-<node>`; `kubectl delete` can't remove them |

---

## 5. Practical 🧪

**Setup:**

```bash
kubectl create deployment web --image=nginx --replicas=3 2>/dev/null || true
```

### Step 1: Prove the kubelet is not a Pod

```bash
kubectl get pods -n kube-system | grep kubelet
docker exec techudaan-worker systemctl status kubelet --no-pager | head -5
```

**Expected:** **nothing** from the first command, and `active (running)` from the second.

**What this proves:** the kubelet runs as a system service on the node. It has to, because it's the thing that starts Pods.

```bash
sudo systemctl status kubelet
sudo systemctl is-active kubelet
which kubelet
kind get clusters
kubectl config current-context
kubectl get nodes
docker exec techudaan-worker systemctl status kubelet
```

### Step 2: Read its config and logs

```bash
docker exec techudaan-worker grep -E "staticPodPath|cgroupDriver|healthzPort|maxPods" /var/lib/kubelet/config.yaml
docker exec techudaan-worker journalctl -u kubelet --no-pager -n 15
```

**Expected:** `staticPodPath: /etc/kubernetes/manifests`, the cgroup driver, and recent log lines.

**What this proves:** when a node misbehaves, `journalctl -u kubelet` is where you look first.

### Step 3: Watch the heartbeat

```bash
kubectl get leases -n kube-node-lease
kubectl get lease techudaan-worker -n kube-node-lease -o jsonpath='{.spec.renewTime}{"\n"}'
sleep 15
kubectl get lease techudaan-worker -n kube-node-lease -o jsonpath='{.spec.renewTime}{"\n"}'
```

**Expected:** one Lease per node, and the `renewTime` changes between the two checks.

**What this proves:** the kubelet keeps renewing its Lease. That's the heartbeat the node lifecycle controller watches.

### Step 4: See what the kubelet reports about its node

```bash
kubectl describe node techudaan-worker | sed -n '/Conditions:/,/Addresses:/p'
kubectl describe node techudaan-worker | grep -A6 "Allocatable:"
```

**Expected:** conditions like `MemoryPressure False`, `DiskPressure False`, `Ready True`, plus the CPU, memory and max Pods this node offers.

**What this proves:** everything the scheduler knows about a node's capacity comes from the kubelet's reports.

### Step 5: Liveness probe, the kubelet restarts a "sick" container

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: sick-app
spec:
  containers:
    - name: nginx
      image: nginx
      livenessProbe:
        httpGet:
          path: /health-does-not-exist
          port: 80
        initialDelaySeconds: 5
        periodSeconds: 5
        failureThreshold: 2
EOF
kubectl get pod sick-app -w
```

Wait about a minute, then press `Ctrl+C`.

```bash
kubectl describe pod sick-app | grep -iE "liveness|restart|killing" | tail -5
```

**Expected:** the `RESTARTS` count keeps going up, and events show `Liveness probe failed: HTTP probe failed with statuscode: 404` followed by `Killing`.

**What this proves:** the kubelet checks container health and restarts containers that fail, with nobody watching.

### Step 6: CrashLoopBackOff, the kubelet backs off

```bash
kubectl run crashy --image=busybox:1.36 -- sh -c "echo starting; exit 1"
kubectl get pod crashy -w
```

After about a minute, press `Ctrl+C`.

**Expected:** `Error` → `CrashLoopBackOff`, with longer waits between each restart.

```bash
kubectl logs crashy
kubectl logs crashy --previous
```

**What this proves:** when a container keeps crashing, the kubelet keeps retrying, but waits longer each time (10s, 20s, 40s… up to 5 minutes) so it doesn't overload the node.

### Step 7: Create a static Pod

Put a Pod file straight into the kubelet's folder. No `kubectl`, no API server, no scheduler:

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
sleep 20
kubectl get pods -o wide | grep static
```

**Expected:** `static-web-techudaan-worker` running on `techudaan-worker`.

Try to delete it:

```bash
kubectl delete pod static-web-techudaan-worker
sleep 5
kubectl get pods | grep static
```

**Expected:** it's back. Check who owns it:

```bash
kubectl get pod static-web-techudaan-worker -o jsonpath='{.metadata.ownerReferences[0].kind}{"\n"}'
```

**Expected:** `Node`. The only way to remove it is to delete the file:

```bash
docker exec techudaan-worker rm /etc/kubernetes/manifests/static-web.yaml
```

**What this proves:** this is exactly how the control plane starts itself. The kubelet runs the API server, etcd, scheduler and controller manager from files, before any API server exists.

### Clean up

```bash
kubectl delete pod sick-app crashy
```

---

## 6. Break It and Fix It 💥

> ⚠️ Lab cluster only.

**Break:** stop the kubelet on a worker.

```bash
docker exec techudaan-worker systemctl stop kubelet
kubectl get nodes -w
```

**Observe:** within about a minute, `techudaan-worker` turns `NotReady`. Press `Ctrl+C`, then:

```bash
kubectl describe node techudaan-worker | grep -iE "kubelet stopped|Unknown" | head -4
kubectl get lease techudaan-worker -n kube-node-lease -o jsonpath='{.spec.renewTime}{"\n"}'
```

The Lease stops renewing, and the conditions show `Unknown`: "Kubelet stopped posting node status." After about 5 minutes (the default), Pods on that node are evicted and recreated on `techudaan-worker2`.

**Fix:**

```bash
docker exec techudaan-worker systemctl start kubelet
kubectl get nodes -w
```

**Lesson:** a node is only "alive" to Kubernetes while its kubelet keeps reporting. `NotReady` → check the kubelet first.

---

## 7. Common Errors

| Status / message | Meaning | First check |
|---|---|---|
| Node `NotReady` | kubelet stopped reporting | `systemctl status kubelet`, `journalctl -u kubelet` |
| `ErrImagePull` / `ImagePullBackOff` | kubelet couldn't get the image | Image name, tag, registry login |
| `CrashLoopBackOff` | Container starts and exits repeatedly | `kubectl logs <pod> --previous` |
| `Liveness probe failed` | Health check failing → restarts | Probe path, port and timing |
| `OOMKilled` | Container used more memory than its limit | Raise the limit or fix the memory use |

---

## 8. Interview Questions 🎤

1. Is the kubelet a Pod? Why or why not?
2. How does the control plane know a node is dead?
3. What's the difference between a liveness and a readiness probe?
4. What is a static Pod, and where is it used?
5. A node shows `NotReady`. What are your first three commands?

<details>
<summary>Answers</summary>

1. No. It's a system service, because it's the component that starts Pods. It can't depend on itself.
2. The kubelet renews a Lease (heartbeat) every few seconds. When renewals stop, the node lifecycle controller marks the node `NotReady`.
3. **Liveness** failing → the kubelet restarts the container. **Readiness** failing → the Pod is removed from Service traffic, but not restarted.
4. A Pod run by the kubelet straight from a file in `/etc/kubernetes/manifests`, with no API server needed. Used to run the control plane itself.
5. `kubectl describe node <node>`; on the node, `systemctl status kubelet`; then `journalctl -u kubelet`.

</details>

---

## ✅ Recap

- The kubelet is a **system service** on every node, and the only component that makes Pods run.
- It runs **probes**, restarts failing containers, and sends **heartbeats**.
- It runs **static Pods** from files, which is how the control plane boots.

➡️ Next: [06. Container runtime, the engine](06-container-runtime.md)
