#!/usr/bin/env bash
# TechUdaan - Day 5: a one-screen report of every node in the cluster.
# Shows status, roles, scheduling, taints, capacity and Pod count per node.
#
# Usage: bash scripts/node-report.sh

if ! kubectl get nodes >/dev/null 2>&1; then
  echo "Can't reach a cluster. Check: kubectl config current-context"
  exit 1
fi

echo "Cluster context: $(kubectl config current-context)"
echo
printf "%-26s %-7s %-15s %-11s %-6s %-8s %-5s %s\n" \
  "NODE" "READY" "ROLES" "SCHEDULING" "CPU" "MEMORY" "PODS" "TAINTS"
printf '%.0s-' {1..110}; echo

for n in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  ready=$(kubectl get node "$n" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
  roles=$(kubectl get node "$n" -o jsonpath='{.metadata.labels}' \
          | tr ',' '\n' | grep -o 'node-role.kubernetes.io/[^"]*' | sed 's#node-role.kubernetes.io/##' | paste -sd, -)
  [ -z "$roles" ] && roles="worker"
  unsched=$(kubectl get node "$n" -o jsonpath='{.spec.unschedulable}')
  [ "$unsched" = "true" ] && sched="CORDONED" || sched="yes"
  cpu=$(kubectl get node "$n" -o jsonpath='{.status.allocatable.cpu}')
  mem_ki=$(kubectl get node "$n" -o jsonpath='{.status.allocatable.memory}' | sed 's/Ki$//')
  if [[ "$mem_ki" =~ ^[0-9]+$ ]]; then mem="$(( mem_ki / 1024 / 1024 ))Gi"; else mem="$mem_ki"; fi
  pods=$(kubectl get pods -A --field-selector spec.nodeName="$n" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  taints=$(kubectl get node "$n" -o jsonpath='{range .spec.taints[*]}{.key}:{.effect} {end}')
  [ -z "$taints" ] && taints="-"
  [ "$ready" = "True" ] && ready="Yes" || ready="NO"
  printf "%-26s %-7s %-15s %-11s %-6s %-8s %-5s %s\n" \
    "$n" "$ready" "$roles" "$sched" "$cpu" "$mem" "$pods" "$taints"
done

echo
echo "CPU and MEMORY = allocatable (what Pods can use, after system reserves)."
