# Stage 1 — VPC & Networking (AWS CLI)

> Prefer clicking through the AWS Console instead? See [`console.md`](./console.md) — same end result, different path. Pick one and stick with it for stages 1-3; everything from Stage 4 onward is identical either way.

Set these on the jumpbox at the start of every session (shell variables don't persist across terminal sessions):
```bash
export CP_IP=<control-plane-private-ip>
export WORKER_IP=<worker-private-ip>
export SERVICE_CLUSTER_IP=10.32.0.1
```

## Create VPC and subnets

```bash
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=k8s-vpc

PUB_SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 \
  --availability-zone <your-az> --query 'Subnet.SubnetId' --output text)
PRIV_SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 \
  --availability-zone <your-az> --query 'Subnet.SubnetId' --output text)
```

## Internet Gateway (public subnet)

```bash
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

PUB_RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $PUB_RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --route-table-id $PUB_RT_ID --subnet-id $PUB_SUBNET_ID
```

## NAT Gateway (private subnet)

The private subnet needs outbound internet access too — for `apt`/binary downloads during setup and for containerd to pull container images later (CoreDNS, and any workload images). The NAT gateway sits in the public subnet and the private route table points to it:

```bash
EIP_ALLOC=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
NAT_GW_ID=$(aws ec2 create-nat-gateway --subnet-id $PUB_SUBNET_ID --allocation-id $EIP_ALLOC --query 'NatGateway.NatGatewayId' --output text)
# wait until the NAT gateway shows "available" (aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GW_ID), then:

PRIV_RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $PRIV_RT_ID --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GW_ID
aws ec2 associate-route-table --route-table-id $PRIV_RT_ID --subnet-id $PRIV_SUBNET_ID
```

With this in place, control-plane and worker can reach the internet directly for the rest of the build — no need to download things on the jumpbox and `scp` them over, though that pattern still works fine if you prefer it.

## If you stop/start instances later

Private IPs stay the same. The jumpbox's public IP changes on every stop/start **unless** it has an Elastic IP attached. Re-export `CP_IP`/`WORKER_IP`/`SERVICE_CLUSTER_IP` at the start of every new session — this is the single most common source of broken systemd services in this build (see the gotchas list in the main README).

Next: [`02-security-groups/cli.md`](../02-security-groups/cli.md) (or [`console.md`](./console.md) for the AWS console version of this stage)
