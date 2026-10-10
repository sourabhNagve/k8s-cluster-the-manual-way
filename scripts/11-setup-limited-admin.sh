#!/usr/bin/env bash
# Run on the JUMPBOX, after the cluster is up. Creates a separate `admin` identity
# (no system:masters) bound to the built-in `admin` ClusterRole via RBAC.
set -euo pipefail

: "${CP_IP:?source 00-env.sh first}"

CERTS_DIR="${CERTS_DIR:-$HOME/k8s-certs}"
cd "$CERTS_DIR"

openssl genrsa -out admin.key 2048
openssl req -new -key admin.key -out admin.csr \
  -subj "/C=US/ST=Oregon/L=Portland/O=k8s-admins/OU=Kubernetes/CN=admin"
openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out admin.crt -days 365

cat > admin-rbac.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: k8s-admins-binding
subjects:
  - kind: Group
    name: k8s-admins
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f admin-rbac.yaml --kubeconfig=super-admin.kubeconfig

kubectl config set-cluster kubernetes-manual \
  --certificate-authority=ca.crt --embed-certs=true \
  --server="https://${CP_IP}:6443" \
  --kubeconfig=admin.kubeconfig
kubectl config set-credentials admin \
  --client-certificate=admin.crt --client-key=admin.key \
  --embed-certs=true --kubeconfig=admin.kubeconfig
kubectl config set-context default \
  --cluster=kubernetes-manual --user=admin \
  --kubeconfig=admin.kubeconfig
kubectl config use-context default --kubeconfig=admin.kubeconfig

echo ""
echo "admin.kubeconfig built. Verifying scope..."
echo "-- admin CAN manage pods:"
kubectl get pods -A --kubeconfig=admin.kubeconfig || true
echo "-- admin should be FORBIDDEN from touching nodes:"
kubectl delete node worker --kubeconfig=admin.kubeconfig --dry-run=server 2>&1 | grep -i forbidden \
  && echo "confirmed: admin is correctly restricted" \
  || echo "WARNING: expected a Forbidden error — check the RBAC binding"
