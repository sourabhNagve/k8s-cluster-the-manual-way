#!/usr/bin/env bash
# Run ON THE CONTROL PLANE (as the ubuntu user, has sudo). Installs and starts etcd.
# Requires: CP_IP set in this shell session (NOT inherited from the jumpbox — re-export here).
set -euo pipefail

: "${CP_IP:?export CP_IP=$(hostname -I | awk '{print \$1}') first, and confirm it is non-blank}"
echo "Using CP_IP=${CP_IP}"

ETCD_VER="${ETCD_VER:-v3.5.18}"

wget -q "https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz"
tar -xzf "etcd-${ETCD_VER}-linux-amd64.tar.gz"
sudo mv "etcd-${ETCD_VER}-linux-amd64"/etcd* /usr/local/bin/

sudo mkdir -p /etc/etcd /var/lib/etcd
sudo chmod 700 /var/lib/etcd
sudo cp ca.crt kube-apiserver.key kube-apiserver.crt /etc/etcd/

cat <<EOF | sudo tee /etc/systemd/system/etcd.service > /dev/null
[Unit]
Description=etcd
Documentation=https://github.com/etcd-io/etcd

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name control-plane \\
  --cert-file=/etc/etcd/kube-apiserver.crt \\
  --key-file=/etc/etcd/kube-apiserver.key \\
  --peer-cert-file=/etc/etcd/kube-apiserver.crt \\
  --peer-key-file=/etc/etcd/kube-apiserver.key \\
  --trusted-ca-file=/etc/etcd/ca.crt \\
  --peer-trusted-ca-file=/etc/etcd/ca.crt \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${CP_IP}:2380 \\
  --listen-peer-urls https://${CP_IP}:2380 \\
  --listen-client-urls https://${CP_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${CP_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster control-plane=https://${CP_IP}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# sanity check: refuse to start if the IP didn't actually get substituted
if grep -q "https://:2380" /etc/systemd/system/etcd.service; then
  echo "ERROR: CP_IP was blank when the unit file was written. Fix CP_IP and re-run."
  exit 1
fi

sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
sleep 2
sudo systemctl status etcd --no-pager

echo ""
echo "Verifying etcd membership..."
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.crt --cert=/etc/etcd/kube-apiserver.crt --key=/etc/etcd/kube-apiserver.key
