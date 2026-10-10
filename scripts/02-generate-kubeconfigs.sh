#!/usr/bin/env bash
# Run on the JUMPBOX, after 01-generate-certs.sh. Requires kubectl installed locally.
# Builds one kubeconfig per identity: kube-proxy, kube-controller-manager,
# kube-scheduler, control-plane (kubelet), worker (kubelet), super-admin.
set -euo pipefail

: "${CP_IP:?source 00-env.sh first}"

CERTS_DIR="${CERTS_DIR:-$HOME/k8s-certs}"
cd "$CERTS_DIR"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found. Install it first:"
  echo '  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"'
  echo "  chmod +x kubectl && sudo mv kubectl /usr/local/bin/"
  exit 1
fi

build_kubeconfig() {
  local name="$1" identity="$2" cert="$3"
  kubectl config set-cluster kubernetes-manual \
    --certificate-authority=ca.crt --embed-certs=true \
    --server="https://${CP_IP}:6443" \
    --kubeconfig="${name}.kubeconfig"

  kubectl config set-credentials "$identity" \
    --client-certificate="${cert}.crt" --client-key="${cert}.key" \
    --embed-certs=true --kubeconfig="${name}.kubeconfig"

  kubectl config set-context default \
    --cluster=kubernetes-manual --user="$identity" \
    --kubeconfig="${name}.kubeconfig"

  kubectl config use-context default --kubeconfig="${name}.kubeconfig"
  echo "built ${name}.kubeconfig"
}

build_kubeconfig "kube-proxy"               "system:kube-proxy"               "kube-proxy"
build_kubeconfig "kube-controller-manager"  "system:kube-controller-manager"  "kube-controller-manager"
build_kubeconfig "kube-scheduler"           "system:kube-scheduler"           "kube-scheduler"
build_kubeconfig "control-plane"            "system:node:control-plane"       "control-plane"
build_kubeconfig "worker"                   "system:node:worker"              "worker"
build_kubeconfig "super-admin"              "super-admin"                     "super-admin"

echo ""
echo "Done. 6 kubeconfigs in $CERTS_DIR"
echo "super-admin.kubeconfig stays on the jumpbox — point kubectl at it for cluster admin work."
