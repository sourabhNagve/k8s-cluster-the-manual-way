# Stage 9 — containerd, runc, CNI plugins, kubelet, kube-proxy

With the NAT gateway in place, download directly on each node that needs it.

```bash
# on BOTH control plane and worker
CONTAINERD_VER=1.7.24
RUNC_VER=1.2.2
CNI_VER=1.6.0
K8S_VER=v1.32.0

wget -q "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VER}/containerd-${CONTAINERD_VER}-linux-amd64.tar.gz"
wget -q "https://github.com/opencontainers/runc/releases/download/v${RUNC_VER}/runc.amd64"
wget -q "https://github.com/containernetworking/plugins/releases/download/v${CNI_VER}/cni-plugins-linux-amd64-v${CNI_VER}.tgz"
wget -q "https://dl.k8s.io/${K8S_VER}/bin/linux/amd64/kubelet"
chmod +x runc.amd64 kubelet
```

```bash
# on worker only, additionally
wget -q "https://dl.k8s.io/${K8S_VER}/bin/linux/amd64/kube-proxy"
chmod +x kube-proxy
```

## On EACH node (control plane AND worker)

```bash
sudo tar -C /usr/local -xzf containerd-*-linux-amd64.tar.gz
chmod +x runc.amd64 && sudo mv runc.amd64 /usr/local/sbin/runc
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins-linux-amd64-*.tgz
chmod +x kubelet && sudo mv kubelet /usr/local/bin/

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable containerd
sudo systemctl start containerd
sudo systemctl status containerd
```

## On the worker only

```bash
chmod +x kube-proxy && sudo mv kube-proxy /usr/local/bin/
```

Next: [`10-worker-node.md`](./10-worker-node.md)
