# Stage 7 — etcd (on control plane)

etcd is the only stateful piece of the control plane — everything else reads/writes through it.

With the NAT gateway in place (`01-networking.md`), the control plane has direct internet access, so download straight on the control plane:
```bash
# on control plane
ETCD_VER=v3.5.18
wget -q "https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz"
```

```bash
tar -xvf etcd-*-linux-amd64.tar.gz
sudo mv etcd-*-linux-amd64/etcd* /usr/local/bin/

sudo mkdir -p /etc/etcd /var/lib/etcd
sudo chmod 700 /var/lib/etcd
sudo cp ca.crt kube-apiserver.key kube-apiserver.crt /etc/etcd/

export CP_IP=$(hostname -I | awk '{print $1}')   # confirm non-blank before writing the file below!
echo $CP_IP

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
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

sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
sudo systemctl status etcd
```

**⚠️ Gotcha hit in this build:** if `$CP_IP` is blank/unset when the heredoc above runs, systemd silently writes `https://:2380` (no IP before the colon) into the unit file, and etcd fails immediately with `expected IP in URL for binding`. Always `echo $CP_IP` right before this step — this bit us after a stop/start reset the shell session.

## Verify

```bash
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.crt --cert=/etc/etcd/kube-apiserver.crt --key=/etc/etcd/kube-apiserver.key
```

Next: [`08-control-plane.md`](./08-control-plane.md)
