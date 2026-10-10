# Stage 11 — Pod Network Routes

No overlay CNI (no Flannel/Calico) — each node knows its own pod CIDR slice, but nothing tells any node how to reach another node's pods. This stage adds static routes.

```bash
export CP_POD_CIDR=10.200.0.0/24
export WORKER_POD_CIDR=10.200.1.0/24

# on control plane
sudo ip route add ${WORKER_POD_CIDR} via ${WORKER_IP}

# on worker
sudo ip route add ${CP_POD_CIDR} via ${CP_IP}
```

## Make persistent (systemd oneshot — example for control plane, mirror on worker with swapped values)

```bash
cat <<EOF | sudo tee /etc/systemd/system/pod-route.service
[Unit]
Description=Static route to worker pod CIDR
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/sbin/ip route add ${WORKER_POD_CIDR} via ${WORKER_IP}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable pod-route.service
```

**Required on AWS:** source/destination check must be disabled on both private instances (see `03-launch-instances.md`) or this routing is silently dropped even though it's configured correctly.

## Verify

```bash
ip route                                                    # on each node
kubectl get nodes --kubeconfig=super-admin.kubeconfig -o wide     # from jumpbox
```

Next: [`12-coredns.md`](./12-coredns.md)
