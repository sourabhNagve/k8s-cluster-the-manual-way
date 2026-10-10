# Stage 10 — Bring the Worker Online (kubelet + kube-proxy)

On the worker:
```bash
sudo mkdir -p /var/lib/kubernetes/ /var/lib/kubelet /var/lib/kube-proxy /etc/cni/net.d

sudo cp ca.crt /var/lib/kubernetes/
sudo cp ca.crt worker.key worker.crt /var/lib/kubelet/
sudo cp worker.kubeconfig /var/lib/kubelet/kubeconfig
sudo cp kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

export POD_CIDR=10.200.1.0/24   # worker's slice of the overall 10.200.0.0/16 pod range

cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
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

cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "1.0.0",
    "name": "lo",
    "type": "loopback"
}
EOF

cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
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

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
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

cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: /var/lib/kube-proxy/kubeconfig
mode: iptables
clusterCIDR: 10.200.0.0/16
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
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
sudo systemctl status kubelet kube-proxy
```

**Note:** `--hostname-override=worker` must exactly match the kubelet cert's CN (`system:node:worker`), or the Node Authorizer rejects the node.

## Verify from jumpbox

```bash
kubectl get nodes --kubeconfig=super-admin.kubeconfig
```
Expect `NotReady` at this point — pod network routes (next stage) and CoreDNS aren't set up yet.

Next: [`11-pod-network-routes.md`](./11-pod-network-routes.md)
