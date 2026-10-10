# Stage 2 — Security Groups (AWS CLI)

> Prefer the AWS Console? See [`console.md`](./console.md).

Two groups: one for the jumpbox, one shared by control-plane + worker (they need near-identical rules, so splitting further adds bookkeeping with little benefit at this scale).

## jumpbox-sg

```bash
JUMP_SG=$(aws ec2 create-security-group --group-name jumpbox-sg --description "jumpbox" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $JUMP_SG --protocol tcp --port 22 --cidr <YOUR_IP>/32
```

## k8s-nodes-sg (control plane + worker)

```bash
K8S_SG=$(aws ec2 create-security-group --group-name k8s-nodes-sg --description "control plane + worker" --vpc-id $VPC_ID --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $K8S_SG --protocol tcp --port 22 --source-group $JUMP_SG
aws ec2 authorize-security-group-ingress --group-id $K8S_SG --protocol tcp --port 6443 --source-group $JUMP_SG
aws ec2 authorize-security-group-ingress --group-id $K8S_SG --protocol tcp --port 6443 --source-group $K8S_SG
aws ec2 authorize-security-group-ingress --group-id $K8S_SG --protocol tcp --port 2379-2380 --source-group $K8S_SG
aws ec2 authorize-security-group-ingress --group-id $K8S_SG --protocol tcp --port 10250-10252 --source-group $K8S_SG
aws ec2 authorize-security-group-ingress --group-id $K8S_SG --protocol tcp --port 30000-32767 --source-group $K8S_SG

# Pod CIDR traffic — we use static routes instead of an overlay CNI (see 11-pod-network-routes.md)
aws ec2 authorize-security-group-ingress --group-id $K8S_SG --protocol -1 --cidr 10.200.0.0/16
```

**Gotcha:** `--cidr` and `--source-group` cannot be mixed in a single `authorize-security-group-ingress` call. Each rule uses one or the other, never both.

Next: [`03-launch-instances/cli.md`](../03-launch-instances/cli.md) (or [`console.md`](./console.md) for the AWS console version of this stage)
