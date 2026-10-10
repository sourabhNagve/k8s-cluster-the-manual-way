#!/usr/bin/env bash
# Run on the JUMPBOX, after scripts 01-03. scp's the right certs/kubeconfigs/config
# to the control-plane and worker. Needs SSH access already working (agent-forwarded key).
set -euo pipefail

: "${CP_IP:?source 00-env.sh first}"
: "${WORKER_IP:?source 00-env.sh first}"

CERTS_DIR="${CERTS_DIR:-$HOME/k8s-certs}"
SSH_USER="${SSH_USER:-ubuntu}"
cd "$CERTS_DIR"

echo "Copying to control plane ($CP_IP)..."
scp ca.crt ca.key kube-apiserver.crt kube-apiserver.key \
    service-accounts.crt service-accounts.key \
    kube-controller-manager.crt kube-controller-manager.key \
    kube-scheduler.crt kube-scheduler.key \
    control-plane.crt control-plane.key \
    control-plane.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig \
    encryption-config.yaml \
    "${SSH_USER}@${CP_IP}:~/"

echo "Copying to worker ($WORKER_IP)..."
scp ca.crt worker.crt worker.key \
    kube-proxy.crt kube-proxy.key \
    worker.kubeconfig kube-proxy.kubeconfig \
    "${SSH_USER}@${WORKER_IP}:~/"

echo ""
echo "Done. super-admin.kubeconfig (and admin.kubeconfig, if generated) stay on the jumpbox."
