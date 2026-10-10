# Stage 14 — Limited `admin` (RBAC-scoped, not `system:masters`)

`super-admin` (Stage 4) uses `O=system:masters`, which Kubernetes treats as an unconditional bypass of RBAC — it can't be scoped down, by design. For day-to-day work, a separate `admin` identity with only the permissions it actually needs is safer. This stage adds that identity, bound through RBAC instead of the hardcoded group.

Run the cert/kubeconfig generation on the **jumpbox**; apply the RBAC binding using `super-admin.kubeconfig`, since creating RBAC objects is itself a privileged action.

## 1. Generate the `admin` cert — no `system:masters` this time

```bash
cd ~/k8s-certs

openssl genrsa -out admin.key 2048

openssl req -new -key admin.key -out admin.csr \
  -subj "/C=US/ST=Oregon/L=Portland/O=k8s-admins/OU=Kubernetes/CN=admin"

openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out admin.crt -days 365
```
`O=k8s-admins` is a made-up group name — it carries **zero** built-in permissions until explicitly granted via RBAC below.

## 2. Bind that group to the built-in `admin` ClusterRole

Kubernetes ships several default ClusterRoles: `cluster-admin` (unrestricted — equivalent to `system:masters`), `admin` (full control over workloads/resources in a namespace or cluster-wide, but **not** nodes, RBAC itself, or other cluster-scoped resources), `edit`, and `view`. The built-in `admin` role is what "necessary but not ultra" rights maps to:

```bash
cat > admin-rbac.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: k8s-admins-binding
subjects:
  - kind: Group
    name: k8s-admins
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f admin-rbac.yaml --kubeconfig=super-admin.kubeconfig
```

With this, `admin` can create/edit/delete Pods, Deployments, Services, ConfigMaps, Secrets, etc. across namespaces. It **cannot** manage Nodes, create/modify ClusterRoles or ClusterRoleBindings, touch cluster-scoped resources like PersistentVolumes, or otherwise escalate its own privileges.

**Narrower option — single namespace instead of cluster-wide:** swap the `ClusterRoleBinding` for a `RoleBinding` in that namespace:
```bash
cat > admin-rbac-namespaced.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: k8s-admins-binding
  namespace: <your-namespace>
subjects:
  - kind: Group
    name: k8s-admins
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f admin-rbac-namespaced.yaml --kubeconfig=super-admin.kubeconfig
```

## 3. Build the `admin` kubeconfig

```bash
kubectl config set-cluster kubernetes-manual \
  --certificate-authority=ca.crt --embed-certs=true \
  --server=https://${CP_IP}:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=admin.crt --client-key=admin.key \
  --embed-certs=true --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-manual --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig
```

## 4. Verify the split actually works

```bash
# super-admin can do anything, including touching nodes:
kubectl get nodes --kubeconfig=super-admin.kubeconfig

# admin can manage workloads:
kubectl get pods -A --kubeconfig=admin.kubeconfig

# admin should be REJECTED touching nodes or RBAC:
kubectl delete node worker --kubeconfig=admin.kubeconfig
# expect: Error from server (Forbidden)
```

From here on, use `admin.kubeconfig` for routine work and reserve `super-admin.kubeconfig` for things that genuinely need it (RBAC changes, node management, cluster-level troubleshooting).
