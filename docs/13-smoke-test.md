# Stage 13 — Smoke Test

End-to-end confirmation that certs, etcd, control plane, worker, pod networking, and DNS are all actually working together.

## DNS resolution

```bash
kubectl run busybox --image=busybox:1.36 --restart=Never --command --kubeconfig=super-admin.kubeconfig -- sleep 3600
kubectl exec -it busybox --kubeconfig=super-admin.kubeconfig -- nslookup kubernetes.default
```
A resolved IP back means DNS, the API server, and the pod network are all wired up correctly.

## Pod-to-pod networking

```bash
kubectl run nginx --image=nginx --kubeconfig=super-admin.kubeconfig
kubectl get pods -o wide --kubeconfig=super-admin.kubeconfig
kubectl exec -it busybox --kubeconfig=super-admin.kubeconfig -- wget -qO- <nginx-pod-ip>
```
A response back confirms the static pod network routes (`11-pod-network-routes.md`) are actually functioning, not just configured.

## Clean up test pods

```bash
kubectl delete pod busybox nginx --kubeconfig=super-admin.kubeconfig
```

## Optional next steps

- **Add a second worker** — repeat `04-certificates.md` (cert), `05-kubeconfigs.md` (kubeconfig), `09-container-runtime.md` + `10-worker-node.md` (containerd/kubelet/kube-proxy) with a new pod CIDR slice (e.g. `10.200.2.0/24`) and a new static route pair in both directions.
- **Taint the control plane** if it shouldn't schedule regular workloads:
  ```bash
  kubectl taint nodes control-plane node-role.kubernetes.io/control-plane:NoSchedule --kubeconfig=super-admin.kubeconfig
  ```
- **Remove the NAT gateway** if you don't need ongoing internet access, to stop the hourly charge — fall back to the manual image-import trick in `12-coredns.md`'s appendix if you do.
- **Back up etcd periodically** — `/var/lib/etcd` on the control plane is the only thing holding real cluster state; everything else (certs, configs) can be regenerated from the jumpbox, but etcd's data can't be recreated after the fact. `etcdctl snapshot save` is worth scheduling if this cluster matters beyond learning.
