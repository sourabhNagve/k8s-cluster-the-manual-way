# Stage 1 — VPC & Networking (AWS Console)

> Prefer the CLI? See [`cli.md`](./cli.md) — same end result, different path.

## 1. Create the VPC

1. Go to **VPC Console** → **Your VPCs** → **Create VPC**.
2. Choose **VPC only**.
3. Name tag: `k8s-vpc`. IPv4 CIDR: `10.0.0.0/16`. Leave everything else default.
4. **Create VPC**.

## 2. Create the two subnets

1. In the VPC Console, go to **Subnets** → **Create subnet**.
2. VPC ID: select `k8s-vpc`.
3. Add subnet 1:
   - Name: `public-subnet`
   - Availability Zone: pick one (any is fine for this build)
   - IPv4 CIDR: `10.0.1.0/24`
4. **Add new subnet**, then subnet 2:
   - Name: `private-subnet`
   - Availability Zone: same as above
   - IPv4 CIDR: `10.0.2.0/24`
5. **Create subnet**.

## 3. Create and attach an Internet Gateway

1. **Internet Gateways** → **Create internet gateway**. Name: `k8s-igw`. **Create**.
2. Select it → **Actions** → **Attach to VPC** → choose `k8s-vpc`.

## 4. Create a NAT Gateway

1. **NAT Gateways** → **Create NAT gateway**.
2. Subnet: `public-subnet` (NAT gateways must sit in a public subnet).
3. Connectivity type: **Public**.
4. **Allocate Elastic IP** (button right there in the form) to give it one automatically.
5. **Create NAT gateway**. Wait a minute or two until its status shows **Available** before continuing — route table changes below will silently not work until it is.

## 5. Route tables

**Public route table:**
1. **Route Tables** → **Create route table**. Name: `public-rt`, VPC: `k8s-vpc`. **Create**.
2. Select it → **Routes** tab → **Edit routes** → **Add route**: destination `0.0.0.0/0`, target → **Internet Gateway** → `k8s-igw`. **Save**.
3. **Subnet associations** tab → **Edit subnet associations** → check `public-subnet`. **Save**.

**Private route table:**
1. **Create route table** again. Name: `private-rt`, VPC: `k8s-vpc`. **Create**.
2. **Edit routes** → **Add route**: destination `0.0.0.0/0`, target → **NAT Gateway** → select the one you created. **Save**.
3. **Edit subnet associations** → check `private-subnet`. **Save**.

## Later, once instances exist: disable source/destination check

After launching the control-plane and worker instances (Stage 3), this step matters for the pod network routes later:
1. **EC2 Console** → **Instances** → select the control-plane instance.
2. **Actions** → **Networking** → **Change source/destination check**.
3. Select **Stop** → **Save**.
4. Repeat for the worker instance.

## If you stop/start instances later

Private IPs stay the same across a stop/start. The jumpbox's public IP changes **unless** it has an Elastic IP attached (EC2 Console → **Elastic IPs** → **Allocate Elastic IP address** → **Actions** → **Associate Elastic IP address** → select the jumpbox instance).

Next: [`../02-security-groups/console.md`](../02-security-groups/console.md) (or [`cli.md`](../02-security-groups/cli.md) if you'd rather switch to the CLI from here)
