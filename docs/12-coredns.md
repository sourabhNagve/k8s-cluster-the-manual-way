# Stage 12 — CoreDNS

Lets Pods resolve service names instead of needing raw IPs. Runs as the first real workload Pod on the cluster, at the fixed address `10.32.0.10` (matches the `clusterDNS` value set in `10-worker-node.md`).

## Apply the manifest

CoreDNS's image is pulled from `registry.k8s.io` on apply — this works because the NAT gateway set up in `01-networking.md` gives the worker outbound internet access. If you're running without a NAT gateway, see the appendix below for a manual image-import workaround instead.

The manifest lives at [`../manifests/coredns.yaml`](../manifests/coredns.yaml).

```bash
kubectl apply -f ../manifests/coredns.yaml --kubeconfig=super-admin.kubeconfig
```

## Verify

```bash
kubectl get pods -n kube-system --kubeconfig=super-admin.kubeconfig
```
Expect `Pending` → `ContainerCreating` → `Running` within about 30-60 seconds (scheduling is near-instant; most of that time is the image pull). If it sticks in `ContainerCreating` far longer than that:
```bash
kubectl describe pod <coredns-pod-name> -n kube-system --kubeconfig=super-admin.kubeconfig
```
Check the Events section at the bottom — usually points straight at an image-pull problem or a CNI config issue.

**Gotcha hit in this build:** before CoreDNS ever got scheduled, we had `0` ReplicaSets and `Events: <none>` on the Deployment — meaning kube-controller-manager wasn't reconciling it at all. That turned out to be the missing `ca.key` issue documented in `08-control-plane.md`, not a CoreDNS-specific problem. Worth ruling out first if nothing happens after `kubectl apply`.

Next: [`13-smoke-test.md`](./13-smoke-test.md)

---

## Appendix: pulling images without a NAT gateway

Only relevant if you want to avoid a NAT gateway permanently. Pull on the jumpbox, save, scp to the node, load directly into containerd — bypasses the network pull entirely:
```bash
# on jumpbox
docker pull <image>
docker save <image> -o image.tar
scp image.tar ubuntu@${WORKER_IP}:~/

# on worker
sudo ctr -n k8s.io images import image.tar
```
This has to be repeated for every new image you ever deploy, so it's only worth it if you specifically want to keep the cluster fully air-gapped.
