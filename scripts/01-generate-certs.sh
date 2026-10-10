#!/usr/bin/env bash
# Run on the JUMPBOX. Generates the CA and every component certificate.
# Requires: CP_IP, WORKER_IP, SERVICE_CLUSTER_IP (source ../00-env.sh first)
set -euo pipefail

: "${CP_IP:?source 00-env.sh first}"
: "${WORKER_IP:?source 00-env.sh first}"
: "${SERVICE_CLUSTER_IP:?source 00-env.sh first}"

CERTS_DIR="${CERTS_DIR:-$HOME/k8s-certs}"
mkdir -p "$CERTS_DIR" && cd "$CERTS_DIR"
echo "Generating certs in $CERTS_DIR"

# --- CA ---
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -days 3650 -out ca.crt \
  -subj "/C=US/ST=Oregon/L=Portland/O=Kubernetes/OU=CA/CN=Kubernetes"

# --- super-admin (O=system:masters — unrestricted, bypasses RBAC) ---
openssl genrsa -out super-admin.key 2048
openssl req -new -key super-admin.key -out super-admin.csr \
  -subj "/C=US/ST=Oregon/L=Portland/O=system:masters/OU=Kubernetes/CN=super-admin"
openssl x509 -req -in super-admin.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out super-admin.crt -days 365

# --- service-accounts ---
openssl genrsa -out service-accounts.key 2048
openssl req -new -key service-accounts.key -out service-accounts.csr \
  -subj "/C=US/ST=Oregon/L=Portland/O=Kubernetes/OU=Kubernetes/CN=service-accounts"
openssl x509 -req -in service-accounts.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out service-accounts.crt -days 365

# --- kube-controller-manager ---
openssl genrsa -out kube-controller-manager.key 2048
openssl req -new -key kube-controller-manager.key -out kube-controller-manager.csr \
  -subj "/C=US/ST=Oregon/L=Portland/O=system:kube-controller-manager/OU=Kubernetes/CN=system:kube-controller-manager"
openssl x509 -req -in kube-controller-manager.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out kube-controller-manager.crt -days 365

# --- kube-scheduler ---
openssl genrsa -out kube-scheduler.key 2048
openssl req -new -key kube-scheduler.key -out kube-scheduler.csr \
  -subj "/C=US/ST=Oregon/L=Portland/O=system:kube-scheduler/OU=Kubernetes/CN=system:kube-scheduler"
openssl x509 -req -in kube-scheduler.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out kube-scheduler.crt -days 365

# --- kube-proxy ---
openssl genrsa -out kube-proxy.key 2048
openssl req -new -key kube-proxy.key -out kube-proxy.csr \
  -subj "/C=US/ST=Oregon/L=Portland/O=system:node-proxier/OU=Kubernetes/CN=system:kube-proxy"
openssl x509 -req -in kube-proxy.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out kube-proxy.crt -days 365

# --- kube-apiserver (needs SANs) ---
cat > openssl-apiserver.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = dn
[dn]
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
IP.1 = ${SERVICE_CLUSTER_IP}
IP.2 = ${CP_IP}
IP.3 = 127.0.0.1
EOF
openssl genrsa -out kube-apiserver.key 2048
openssl req -new -key kube-apiserver.key -out kube-apiserver.csr \
  -subj "/C=US/ST=Oregon/L=Portland/O=Kubernetes/OU=Kubernetes/CN=kube-apiserver" \
  -config openssl-apiserver.cnf
openssl x509 -req -in kube-apiserver.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out kube-apiserver.crt -days 365 -extensions v3_req -extfile openssl-apiserver.cnf

# --- control-plane kubelet cert ---
cat > openssl-cp-kubelet.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = dn
[dn]
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = ${CP_IP}
EOF
openssl genrsa -out control-plane.key 2048
openssl req -new -key control-plane.key -out control-plane.csr \
  -subj "/C=US/ST=Oregon/L=Portland/O=system:nodes/OU=Kubernetes/CN=system:node:control-plane" \
  -config openssl-cp-kubelet.cnf
openssl x509 -req -in control-plane.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out control-plane.crt -days 365 -extensions v3_req -extfile openssl-cp-kubelet.cnf

# --- worker kubelet cert ---
cat > openssl-worker-kubelet.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = dn
[dn]
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = ${WORKER_IP}
EOF
openssl genrsa -out worker.key 2048
openssl req -new -key worker.key -out worker.csr \
  -subj "/C=US/ST=Oregon/L=Portland/O=system:nodes/OU=Kubernetes/CN=system:node:worker" \
  -config openssl-worker-kubelet.cnf
openssl x509 -req -in worker.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out worker.crt -days 365 -extensions v3_req -extfile openssl-worker-kubelet.cnf

echo ""
echo "Done. Certs are in $CERTS_DIR"
echo "Reminder: set real hostnames on the nodes to match the kubelet cert CNs:"
echo "  on control plane: sudo hostnamectl set-hostname control-plane"
echo "  on worker:        sudo hostnamectl set-hostname worker"
