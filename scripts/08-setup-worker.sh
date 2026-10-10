#!/usr/bin/env bash
# Run ON THE WORKER, after 07-setup-container-runtime.sh. Installs and starts
# kubelet + kube-proxy, and sets up this node's CNI config.
set -euo pipefail

: "${POD_CIDR:=10.200.1.0/24}"
echo "Using POD_CIDR=${POD_CIDR}"

sudo mkdir -p /var/lib/kubernetes/ /var/lib/kubelet /var/lib/kube-proxy /etc/cni/net.d

sudo cp ca.crt /var/lib/kubernetes/
sudo cp ca.crt worker.key worker.crt /var/lib/kubelet/
sudo cp worker.kubeconfig /var/lib/kubelet/kubeconfig
sudo cp kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
sudo mv kube-proxy /usr/local/bin/ 2>/dev/null || true  # no-op if already moved

cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf > /dev/null
{
    "cniVersion": "1.0.0",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [[{"subnet": "${POD_CIDR}"}]],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf > /dev/null
{
    "cniVersion": "1.0.0",
    "name": "lo",
    "type": "loopback"
}
EOF

cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml > /dev/null
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: /var/lib/kubelet/ca.crt
authorization:
  mode: Webhook
clusterDomain: cluster.local
clusterDNS:
  - 10.32.0.10
podCIDR: ${POD_CIDR}
resolvConf: /run/systemd/resolve/resolv.conf
runtimeRequestTimeout: 15m
tlsCertFile: /var/lib/kubelet/worker.crt
tlsPrivateKeyFile: /var/lib/kubelet/worker.key
EOF

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service > /dev/null
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime-endpoint=unix:///run/containerd/containerd.sock \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --register-node=true \\
  --hostname-override=worker \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml > /dev/null
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: /var/lib/kube-proxy/kubeconfig
mode: iptables
clusterCIDR: 10.200.0.0/16
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service > /dev/null
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable kubelet kube-proxy
sudo systemctl start kubelet kube-proxy
sleep 2
sudo systemctl status kubelet kube-proxy --no-pager

echo ""
echo "Verify from the jumpbox with:"
echo "  kubectl get nodes --kubeconfig=super-admin.kubeconfig"
