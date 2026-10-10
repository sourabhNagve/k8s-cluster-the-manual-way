# Scripts

Runnable versions of the commands in `../docs/`. Same build, less copy-pasting. Each script is standalone and matches one or more doc stages — read the doc first if you want to understand *why* a step exists, use the script to actually run it.

| Script | Run on | Matches doc stage |
|---|---|---|
| `00-env.sh` | jumpbox (source, don't execute) | — |
| `01-generate-certs.sh` | jumpbox | `04-certificates.md` |
| `02-generate-kubeconfigs.sh` | jumpbox | `05-kubeconfigs.md` |
| `03-generate-encryption-config.sh` | jumpbox | `06-encryption-config.md` |
| `04-distribute.sh` | jumpbox | `05-kubeconfigs.md` (distribution section) |
| `05-setup-etcd.sh` | control plane | `07-etcd.md` |
| `06-setup-control-plane.sh` | control plane | `08-control-plane.md` |
| `07-setup-container-runtime.sh` | **both** control plane and worker | `09-container-runtime.md` |
| `08-setup-worker.sh` | worker | `10-worker-node.md` |
| `09-setup-pod-route.sh` | **both**, with different args | `11-pod-network-routes.md` |
| `10-deploy-coredns.sh` | jumpbox | `12-coredns.md` |
| `11-setup-limited-admin.sh` | jumpbox | `14-limited-admin.md` |

## Usage

On the jumpbox, every session:
```bash
cd scripts
export CP_IP=<control-plane-private-ip>
export WORKER_IP=<worker-private-ip>
source 00-env.sh
```

Then run, in order:
```bash
./01-generate-certs.sh
./02-generate-kubeconfigs.sh
./03-generate-encryption-config.sh
./04-distribute.sh
```

scp the scripts themselves over to each node (or just copy/paste — they're short):
```bash
scp 05-setup-etcd.sh 06-setup-control-plane.sh 07-setup-container-runtime.sh ubuntu@${CP_IP}:~/
scp 07-setup-container-runtime.sh 08-setup-worker.sh ubuntu@${WORKER_IP}:~/
```

On the **control plane**:
```bash
export CP_IP=$(hostname -I | awk '{print $1}')   # confirm non-blank — see README gotchas
./07-setup-container-runtime.sh
./05-setup-etcd.sh
./06-setup-control-plane.sh
./09-setup-pod-route.sh 10.200.1.0/24 <worker-private-ip>
```

On the **worker**:
```bash
./07-setup-container-runtime.sh
./08-setup-worker.sh
./09-setup-pod-route.sh 10.200.0.0/24 <control-plane-private-ip>
```

Back on the **jumpbox**:
```bash
./10-deploy-coredns.sh
./11-setup-limited-admin.sh   # optional — only if you want the RBAC-scoped admin identity
```

## Notes

- These scripts assume the AWS infra (VPC, security groups, instances) from `docs/01-networking/`, `docs/02-security-groups/`, `docs/03-launch-instances/` already exists — they only cover Stage 4 onward.
- `CP_IP` must be re-exported in **every new shell session**, including separately on the jumpbox and on the control plane itself — it does not carry over via SSH. `05-setup-etcd.sh` and `06-setup-control-plane.sh` will refuse to start their services if they detect a blank IP got baked into the systemd unit.
- `07-setup-container-runtime.sh` is identical on both nodes — just scp it to both and run it as-is.
- None of these scripts touch AWS itself (VPC, security groups, EC2) — see the CLI/console docs for that part, since the right tool depends on which path you chose for Stage 1-3.
