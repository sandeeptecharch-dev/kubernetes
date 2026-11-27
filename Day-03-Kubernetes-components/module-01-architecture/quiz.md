# Module 1: Self-Check Quiz and Interview Questions

🎯 Score **7 out of 8** before moving to Module 2.
Answers are at the end, so try first.

---

## Quiz

1. Which is the only component that reads and writes etcd directly?
2. A new Pod is stuck in `Pending` and `kubectl describe` shows no events at all. Which component is most likely down?
3. Which component runs on every node and actually tells the container runtime to start a Pod?
4. You delete a Pod that belongs to a Deployment and a new one appears within seconds. Which component created it?
5. True or false: if the API server is down, all running apps stop serving users.
6. What gives an app the ability to call another app by name, like `http://payment-service`?
7. On a kind cluster, where do the control-plane Pods' definition files live?
8. In one sentence, what is "reconciliation"?

---

## 🎤 Interview Questions

Practise answering each one **aloud in 60 seconds**. Record yourself if you can.

- Walk me through what happens when I run `kubectl apply -f deployment.yaml`.
- What is etcd, and why must it be backed up?
- What's the difference between the control plane and a worker node?
- A node shows `NotReady`. How would you investigate?
- Why don't Kubernetes components talk to each other directly?

---

## ✅ Answers

<details>
<summary>Click to reveal answers</summary>

1. **kube-apiserver**
2. **kube-scheduler** (no `Scheduled` event, and `NODE` is `<none>`)
3. **kubelet**
4. **The ReplicaSet controller**, which runs inside kube-controller-manager
5. **False.** Running containers keep serving; you just can't make changes or get self-healing.
6. **CoreDNS** (together with a Service)
7. **`/etc/kubernetes/manifests`** on the control-plane node (they are static Pods)
8. Controllers keep comparing **desired state** with **actual state** and act to make them match.

</details>

---

## ➡️ Next: Module 2, Pods

What a Pod really is, why it can hold more than one container, and how to write your first Pod YAML by hand.

👉 [module-02-pods](../module-02-pods/)
