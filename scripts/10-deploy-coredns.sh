#!/usr/bin/env bash
# Run on the JUMPBOX. Applies CoreDNS and waits for it to become Ready.
set -euo pipefail

CERTS_DIR="${CERTS_DIR:-$HOME/k8s-certs}"
MANIFEST="${MANIFEST:-../manifests/coredns.yaml}"

kubectl apply -f "$MANIFEST" --kubeconfig="${CERTS_DIR}/super-admin.kubeconfig"

echo "Waiting for CoreDNS to become Ready (up to 90s)..."
kubectl wait --for=condition=Ready pod -l k8s-app=kube-dns -n kube-system \
  --timeout=90s --kubeconfig="${CERTS_DIR}/super-admin.kubeconfig" || {
    echo "CoreDNS did not become Ready in time. Check:"
    echo "  kubectl describe pod -n kube-system -l k8s-app=kube-dns --kubeconfig=${CERTS_DIR}/super-admin.kubeconfig"
    exit 1
  }

echo "CoreDNS is Running."
kubectl get pods -n kube-system --kubeconfig="${CERTS_DIR}/super-admin.kubeconfig"
