#!/usr/bin/env bash
# Run ON THE CONTROL PLANE, after 05-setup-etcd.sh. Installs and starts
# kube-apiserver, kube-controller-manager, kube-scheduler.
set -euo pipefail

: "${CP_IP:?export CP_IP=$(hostname -I | awk '{print \$1}') first, and confirm it is non-blank}"
echo "Using CP_IP=${CP_IP}"

K8S_VER="${K8S_VER:-v1.32.0}"

wget -q "https://dl.k8s.io/${K8S_VER}/bin/linux/amd64/kube-apiserver" \
        "https://dl.k8s.io/${K8S_VER}/bin/linux/amd64/kube-controller-manager" \
        "https://dl.k8s.io/${K8S_VER}/bin/linux/amd64/kube-scheduler"
chmod +x kube-apiserver kube-controller-manager kube-scheduler
sudo mv kube-apiserver kube-controller-manager kube-scheduler /usr/local/bin/

sudo mkdir -p /etc/kubernetes/config /var/lib/kubernetes/

# NOTE: ca.key is required here (not just ca.crt) — kube-controller-manager's
# CSR-signing controller needs it, and will crash-loop without it.
sudo cp ca.crt ca.key kube-apiserver.crt kube-apiserver.key \
  service-accounts.crt service-accounts.key encryption-config.yaml \
  /var/lib/kubernetes/
sudo cp kube-controller-manager.kubeconfig kube-scheduler.kubeconfig /var/lib/kubernetes/

cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service > /dev/null
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${CP_IP} \\
  --allow-privileged=true \\
  --authorization-mode=Node,RBAC \\
  --client-ca-file=/var/lib/kubernetes/ca.crt \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.crt \\
  --etcd-certfile=/var/lib/kubernetes/kube-apiserver.crt \\
  --etcd-keyfile=/var/lib/kubernetes/kube-apiserver.key \\
  --etcd-servers=https://${CP_IP}:2379 \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.crt \\
  --kubelet-client-certificate=/var/lib/kubernetes/kube-apiserver.crt \\
  --kubelet-client-key=/var/lib/kubernetes/kube-apiserver.key \\
  --runtime-config=api/all=true \\
  --service-account-key-file=/var/lib/kubernetes/service-accounts.crt \\
  --service-account-signing-key-file=/var/lib/kubernetes/service-accounts.key \\
  --service-account-issuer=https://${CP_IP}:6443 \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --tls-cert-file=/var/lib/kubernetes/kube-apiserver.crt \\
  --tls-private-key-file=/var/lib/kubernetes/kube-apiserver.key \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service > /dev/null
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.crt \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca.key \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --root-ca-file=/var/lib/kubernetes/ca.crt \\
  --service-account-private-key-file=/var/lib/kubernetes/service-accounts.key \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml > /dev/null
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: /var/lib/kubernetes/kube-scheduler.kubeconfig
leaderElection:
  leaderElect: true
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service > /dev/null
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

if grep -q "advertise-address=  *\\\\$\|advertise-address= \\\\" /etc/systemd/system/kube-apiserver.service; then
  echo "ERROR: CP_IP looks blank in kube-apiserver.service. Fix CP_IP and re-run."
  exit 1
fi

sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
sleep 3
sudo systemctl status kube-apiserver kube-controller-manager kube-scheduler --no-pager

echo ""
echo "Verify from the jumpbox with:"
echo "  kubectl get componentstatuses --kubeconfig=super-admin.kubeconfig"
