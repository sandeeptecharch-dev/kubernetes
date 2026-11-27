#!/usr/bin/env bash
# TechUdaan - Day 4: check that your kind cluster is healthy.
# Usage: bash scripts/verify-cluster.sh [cluster-name]   (default: techudaan)

CLUSTER="${1:-techudaan}"
CONTEXT="kind-${CLUSTER}"
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
FAIL=0

ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
bad()  { echo -e "${RED}[FAIL]${NC}  $1"; echo -e "        Fix: $2"; FAIL=$((FAIL+1)); }
info() { echo -e "${YELLOW}[INFO]${NC}  $1"; }

echo "=========================================="
echo "  Checking kind cluster: ${CLUSTER}"
echo "=========================================="

# 1. Tools
for t in docker kind kubectl; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t is installed"
  else bad "$t is not installed" "See module-00-setup/README.md"; fi
done
[ "$FAIL" -gt 0 ] && { echo "Install the missing tools first."; exit 1; }

# 2. Docker running
if docker info >/dev/null 2>&1; then ok "Docker is running"
else bad "Docker is not running" "Start Docker Desktop / Colima / 'sudo systemctl start docker'"; exit 1; fi

# 3. Cluster exists
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then ok "Cluster '${CLUSTER}' exists"
else
  bad "Cluster '${CLUSTER}' not found" "kind create cluster --name ${CLUSTER} --config kind-configs/kind-3node.yaml"
  info "Existing clusters: $(kind get clusters 2>/dev/null | tr '\n' ' ')"
  exit 1
fi

# 4. kubectl context
CURRENT=$(kubectl config current-context 2>/dev/null)
if [ "$CURRENT" = "$CONTEXT" ]; then ok "kubectl context is ${CONTEXT}"
else bad "kubectl context is '${CURRENT:-none}', not ${CONTEXT}" "kubectl config use-context ${CONTEXT}"; fi

# 5. API server reachable
if kubectl --context "$CONTEXT" get --raw='/readyz' >/dev/null 2>&1; then ok "API server is ready"
else bad "API server not reachable" "Wait a minute, or: kind export kubeconfig --name ${CLUSTER}"; fi

# 6. Nodes ready
TOTAL=$(kubectl --context "$CONTEXT" get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
READY=$(kubectl --context "$CONTEXT" get nodes --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l | tr -d ' ')
if [ "$TOTAL" -gt 0 ] && [ "$TOTAL" = "$READY" ]; then ok "All ${TOTAL} node(s) are Ready"
else bad "${READY}/${TOTAL} nodes Ready" "kubectl describe node <name>; wait 1-2 min on first start"; fi

# 7. System Pods running
NOTRUN=$(kubectl --context "$CONTEXT" get pods -n kube-system --no-headers 2>/dev/null | awk '$3!="Running" && $3!="Completed"' | wc -l | tr -d ' ')
if [ "$NOTRUN" = "0" ]; then ok "All kube-system Pods are Running"
else bad "${NOTRUN} kube-system Pod(s) not Running" "kubectl get pods -n kube-system"; fi

echo "=========================================="
if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}Cluster '${CLUSTER}' is healthy. Happy hacking! 🚀${NC}"
  kubectl --context "$CONTEXT" get nodes -o wide
  exit 0
else
  echo -e "${RED}${FAIL} problem(s) found. Fix them and run again.${NC}"
  exit 1
fi
