# Kubernetes the Manual Way — on AWS

A hand-built Kubernetes cluster on AWS EC2: Every component — etcd, kube-apiserver, kube-controller-manager, kube-scheduler, kubelet, kube-proxy, containerd — installed and run by hand via systemd, with certs generated manually via openssl.

Inspired by and adapted from Kelsey Hightower's [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way). This is an independent rebuild, not a copy — different tooling (openssl instead of cfssl), a single-control-plane/single-worker topology instead of HA, IP-based certificate SANs instead of hostname-based, and built around a specific AWS VPC layout (public/private subnet + jumpbox + NAT gateway).

## Architecture

```
                         ┌─────────────────────┐
  you ── SSH ──────────► │   jumpbox (public)   │
                         └──────────┬───────────┘
                                    │ SSH (agent-forwarded)
                 ┌──────────────────┴──────────────────┐
                 │                                      │
        ┌────────▼─────────┐                  ┌─────────▼────────┐
        │  control-plane     │                  │     worker        │
        │  (private subnet)  │                  │  (private subnet) │
        │  etcd               │                  │  kubelet          │
        │  kube-apiserver     │◄────────────────►│  kube-proxy       │
        │  kube-scheduler     │                  │  containerd        │
        │  kube-controller-   │                  └────────────────────┘
        │  manager            │
        └─────────────────────┘
```

- **jumpbox** — public subnet, public IP. Only place with your SSH key (via agent forwarding (ssh-add sshkey.pem and then ssh -A ubuntu@<IP>)). Used to generate certs/kubeconfigs and run `kubectl`.
- **control-plane** — private subnet, no public IP. Runs etcd + the three control plane components.
- **worker** — private subnet, no public IP. Runs kubelet, kube-proxy, containerd.

No overlay CNI (no Flannel/Calico) — pod-to-pod networking uses static routes between nodes (see `docs/11-pod-network-routes.md`), which requires disabling AWS's source/destination check on both private instances.

## Prerequisites

- AWS CLI configured or if you are using the graphical interface then no need
- An SSH key pair
- `openssl`, `kubectl` (installed on the jumpbox as part of the build)

## Build order

Follow `docs/` in numeric order — each stage assumes the previous ones are done.

**Stages 1-3** are pure AWS infrastructure setup and are provided two ways — pick whichever you prefer, both land in the same place:
- `cli.md` — AWS CLI commands
- `console.md` — click-through steps in the AWS web console

You can even switch between the two mid-way (e.g. console for networking, CLI for launching instances) — they don't depend on each other's method, only on the resources existing.

**Stage 4 onward** happens entirely inside the terminal on the instances themselves (openssl, systemd, kubectl) — identical regardless of which path you took for 1-3.

| Stage | Folder/File | What it covers |
|---|---|---|
| 1 | `01-networking/` (`cli.md` / `console.md`) | VPC, public/private subnets, IGW, NAT gateway, route tables |
| 2 | `02-security-groups/` (`cli.md` / `console.md`) | `jumpbox-sg`, `k8s-nodes-sg` |
| 3 | `03-launch-instances/` (`cli.md` / `console.md`) | Instance types, AMI, launch, source/dest-check, SSH access |
| 4 | `04-certificates.md` | CA + per-component certs via openssl |
| 5 | `05-kubeconfigs.md` | kubeconfig generation + distribution |
| 6 | `06-encryption-config.md` | etcd Secrets encryption key/config |
| 7 | `07-etcd.md` | etcd install + systemd service |
| 8 | `08-control-plane.md` | kube-apiserver, kube-controller-manager, kube-scheduler |
| 9 | `09-container-runtime.md` | containerd, runc, CNI plugins |
| 10 | `10-worker-node.md` | kubelet + kube-proxy on the worker |
| 11 | `11-pod-network-routes.md` | Static routes between node pod CIDRs |
| 12 | `12-coredns.md` | Cluster DNS |
| 13 | `13-smoke-test.md` | End-to-end verification |
| 14 | `14-limited-admin.md` | RBAC-scoped `admin` identity, separate from the unrestricted `super-admin` |

## Scripts

Everything from Stage 4 onward is also available as runnable scripts in [`scripts/`](./scripts/), if you'd rather not copy-paste commands one block at a time. See [`scripts/README.md`](./scripts/README.md) for usage order — the docs remain the explanation of *why*, the scripts are the *how*.

## Reference

- [`docs/vs-kubeadm.md`](./docs/vs-kubeadm.md) — once the cluster is up, a side-by-side of what this manual build does vs. what kubeadm would have automated, including the folder/file layout each one produces.

## Known gotchas (hit during this build)

- **Blank shell variables in systemd files** — `$CP_IP` etc. don't persist across terminal sessions. Always re-`export` and `echo` to confirm before writing any systemd unit file that embeds a variable.
- **AWS security group rules** — `--cidr` and `--source-group` can't be mixed in a single `authorize-security-group-ingress` call.
- **AWS source/destination check** — must be disabled on both private instances or routed pod traffic is silently dropped.
- **Kubelet `--hostname-override`** must exactly match the node's kubelet certificate CN (`system:node:<name>`), or the Node Authorizer rejects it.
- **Missing `ca.key` on the control plane** — kube-controller-manager needs it (not just `ca.crt`) to run the CSR signing controller; easy to forget when distributing certs.

## License

This repo's own content is provided as-is for learning purposes. See the credit above regarding Kelsey Hightower's original tutorial (CC BY-NC-SA 4.0) — none of his original files are reproduced here, only independently written equivalents.
