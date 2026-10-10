# Stage 5 — kubeconfigs

Built on the **jumpbox**. Each kubeconfig bundles: the API server address + CA cert (so the client trusts the server), the client's own cert+key (so the server trusts the client), and a default context.

## Install kubectl on the jumpbox first

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/
```

## The pattern

Repeat for each identity below:
```bash
kubectl config set-cluster kubernetes-manual \
  --certificate-authority=ca.crt --embed-certs=true \
  --server=https://${CP_IP}:6443 \
  --kubeconfig=<name>.kubeconfig

kubectl config set-credentials <identity> \
  --client-certificate=<cert>.crt --client-key=<cert>.key \
  --embed-certs=true --kubeconfig=<name>.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-manual --user=<identity> \
  --kubeconfig=<name>.kubeconfig

kubectl config use-context default --kubeconfig=<name>.kubeconfig
```

| `<name>.kubeconfig` | `<identity>` | `<cert>` |
|---|---|---|
| kube-proxy | `system:kube-proxy` | kube-proxy |
| kube-controller-manager | `system:kube-controller-manager` | kube-controller-manager |
| kube-scheduler | `system:kube-scheduler` | kube-scheduler |
| control-plane | `system:node:control-plane` | control-plane |
| worker | `system:node:worker` | worker |
| super-admin | `super-admin` | super-admin |

> A second, RBAC-limited `admin` identity (no `system:masters`, scoped via the `admin` ClusterRole) is added later in [`14-limited-admin.md`](./14-limited-admin.md), once the cluster is up and `super-admin.kubeconfig` can be used to apply the RBAC binding.

## Distribute certs & kubeconfigs

```bash
# to control plane
scp ca.crt ca.key kube-apiserver.crt kube-apiserver.key \
    service-accounts.crt service-accounts.key \
    kube-controller-manager.crt kube-controller-manager.key \
    kube-scheduler.crt kube-scheduler.key \
    control-plane.crt control-plane.key \
    control-plane.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig \
    ubuntu@${CP_IP}:~/

# to worker
scp ca.crt worker.crt worker.key \
    kube-proxy.crt kube-proxy.key \
    worker.kubeconfig kube-proxy.kubeconfig \
    ubuntu@${WORKER_IP}:~/
```

`super-admin.kubeconfig` stays on the jumpbox — that's what you point `kubectl` at.

**Gotcha:** `ca.key` (not just `ca.crt`) must be copied to the control plane — `kube-controller-manager` needs it to run its CSR-signing controller. Easy to miss since most other components only need `ca.crt`.

Next: [`06-encryption-config.md`](./06-encryption-config.md)
