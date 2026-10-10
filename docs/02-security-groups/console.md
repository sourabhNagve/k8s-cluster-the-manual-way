# Stage 2 — Security Groups (AWS Console)

> Prefer the CLI? See [`cli.md`](./cli.md).

Two groups: one for the jumpbox, one shared by control-plane + worker.

## 1. Create `jumpbox-sg`

1. **EC2 Console** → **Security Groups** → **Create security group**.
2. Name: `jumpbox-sg`. Description: `jumpbox`. VPC: `k8s-vpc`.
3. **Inbound rules** → **Add rule**:
   - Type: **SSH** (auto-fills port 22)
   - Source: **My IP** (auto-fills your current public IP) — or paste a specific CIDR if you prefer
4. Leave outbound rules as the default (**All traffic** — already there by default).
5. **Create security group**.

## 2. Create `k8s-nodes-sg`

1. **Create security group** again.
2. Name: `k8s-nodes-sg`. Description: `control plane + worker`. VPC: `k8s-vpc`.
3. **Inbound rules** → **Add rule**, repeat for each row below:

| Type | Port range | Source |
|---|---|---|
| SSH | 22 | Custom → `jumpbox-sg` (type the SG name/ID, it'll autocomplete) |
| Custom TCP | 6443 | Custom → `jumpbox-sg` |
| Custom TCP | 6443 | Custom → `k8s-nodes-sg` (self-reference — select this same SG once it's saved once, or add this rule in a second edit pass after creation) |
| Custom TCP | 2379 - 2380 | Custom → `k8s-nodes-sg` |
| Custom TCP | 10250 - 10252 | Custom → `k8s-nodes-sg` |
| Custom TCP | 30000 - 32767 | Custom → `k8s-nodes-sg` |
| All traffic | all | Custom CIDR → `10.200.0.0/16` |

> **Note on self-referencing rules:** the console won't let you select a security group as its own source until it's already been created once. Create the group first with the `jumpbox-sg`-sourced rules, **Create security group**, then go back in and **Edit inbound rules** to add the remaining `k8s-nodes-sg`-sourced rows, now that it exists and is selectable.

4. **Save rules**.

Next: [`../03-launch-instances/console.md`](../03-launch-instances/console.md) (or [`cli.md`](../03-launch-instances/cli.md))
