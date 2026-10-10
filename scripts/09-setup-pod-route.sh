#!/usr/bin/env bash
# Run on EACH node — adds a static route to the OTHER node's pod CIDR, and makes it
# persistent via a oneshot systemd service.
#
# Usage (on control plane): ./09-setup-pod-route.sh 10.200.1.0/24 $WORKER_IP
# Usage (on worker):        ./09-setup-pod-route.sh 10.200.0.0/24 $CP_IP
set -euo pipefail

PEER_POD_CIDR="${1:?Usage: $0 <peer-pod-cidr> <peer-node-ip>}"
PEER_IP="${2:?Usage: $0 <peer-pod-cidr> <peer-node-ip>}"

sudo ip route add "${PEER_POD_CIDR}" via "${PEER_IP}" 2>/dev/null || \
  echo "Route may already exist, continuing..."

cat <<EOF | sudo tee /etc/systemd/system/pod-route.service > /dev/null
[Unit]
Description=Static route to peer node pod CIDR
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/sbin/ip route add ${PEER_POD_CIDR} via ${PEER_IP}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable pod-route.service

echo "Route to ${PEER_POD_CIDR} via ${PEER_IP} added and made persistent."
echo "Reminder: source/destination check must be disabled on this instance in the AWS console/CLI,"
echo "or this routing is silently dropped even though it's configured correctly."
ip route
