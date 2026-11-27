# Module 3: Self-Check Quiz and Interview Questions

🎯 Score **8 out of 10** before moving on.
Answers are at the end, so try first.

---

## Quiz

1. Which control-plane components run as **static Pods**, and which node component runs as a **system service** instead?
2. Name the 3 gates every request passes through in the API server, in order.
3. True or false: Kubernetes Secrets are encrypted in etcd by default.
4. Why does production etcd run 3 or 5 members, never 2 or 4?
5. The scheduler picks a node in two phases. Name them.
6. A Pod shows `0/3 nodes are available: 3 Insufficient memory`. Is the scheduler broken? What would you change?
7. You run `kubectl delete pod X` and it comes back instantly. Its owner is a `Node`. What is it, and how do you remove it?
8. What is the **pause** container for?
9. A Service's ClusterIP is `10.96.45.12`. Which machine owns that IP?
10. An app can reach another app by IP but not by name. Which component do you check first?

---

## 🎤 Interview Questions

Practise answering each one **aloud in 60 seconds**.

- What's the difference between the scheduler and the kubelet? Which one starts the container?
- Kubernetes removed dockershim. Do Docker-built images still work? Why?
- How does kube-proxy make a Service work? Does traffic pass through kube-proxy?
- A Service returns "connection refused" but the Pods are running. How do you debug it?
- What is a static Pod, and where is it used in a real cluster?
- How does the control plane know a node has died?

---

## ✅ Answers

<details>
<summary>Click to reveal answers</summary>

1. **Static Pods:** kube-apiserver, etcd, kube-scheduler, kube-controller-manager. **System service:** the kubelet (and the container runtime).
2. **Authentication** (who are you?) → **Authorization** (are you allowed?) → **Admission** (is it valid?).
3. **False.** They are only base64-encoded unless encryption at rest is turned on.
4. etcd needs a **majority** to agree (Raft). 3 members survive 1 failure, 5 survive 2. Adding a 4th member doesn't let you survive more failures than 3 does.
5. **Filtering** (remove nodes that can't run it) and **scoring** (rank the rest).
6. **No, it's working.** The Pod's memory **request** is bigger than any node's free capacity. Lower the request or add bigger nodes.
7. A **static Pod**. Delete its file from `/etc/kubernetes/manifests` on that node.
8. It holds the Pod's **network namespace**, so all containers in the Pod share one IP.
9. **None.** It's virtual, existing only in the rules kube-proxy writes on each node.
10. **CoreDNS.**

</details>

---

## ➡️ Next Module

Deployments and ReplicaSets: scaling, rolling updates and rollbacks.
