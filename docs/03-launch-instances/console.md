# Stage 3 — Launch Instances (AWS Console)

> Prefer the CLI? See [`cli.md`](./cli.md).

Launch three separate instances — repeat **Launch instance** three times with the settings below.

## Common steps for all three

1. **EC2 Console** → **Instances** → **Launch instance**.
2. **Application and OS Images**: search "Ubuntu", select **Ubuntu Server 22.04 LTS** (make sure it's the free-tier-eligible, 64-bit (x86) version).
3. **Key pair**: select your existing key pair (or create one here if you haven't).
4. **Network settings** → **Edit**:
   - VPC: `k8s-vpc`
   - Subnet: see table below per instance
   - Auto-assign public IP: see table below
   - Firewall (security groups): **Select existing security group** → pick the right one per instance below

## Per-instance settings

| Instance | Name | Instance type | Subnet | Auto-assign public IP | Security group |
|---|---|---|---|---|---|
| 1 | `jumpbox` | `t3.micro` | `public-subnet` | **Enable** | `jumpbox-sg` |
| 2 | `control-plane` | `t3.medium` | `private-subnet` | **Disable** | `k8s-nodes-sg` |
| 3 | `worker` | `t3.medium` | `private-subnet` | **Disable** | `k8s-nodes-sg` |

5. Leave storage at default (8-20 GB is plenty for this build).
6. **Launch instance**.

Repeat for all three, double-checking the Name tag each time so they're easy to tell apart in the instance list.

## Disable source/destination check (control-plane and worker only)

Required later for pod network routes to work — AWS drops traffic by default where the packet's source/destination IP doesn't match the instance's own network interface.

1. **Instances** → select `control-plane`.
2. **Actions** → **Networking** → **Change source/destination check**.
3. Select **Stop** (this disables the check — the label is a little confusing, but "Stop" here means "stop checking"). **Save**.
4. Repeat for `worker`.

## Access pattern

Find each instance's IP from the **Instances** list (click the instance → **Networking** tab shows both public and private IPs).

Use SSH agent forwarding so your private key never has to live on the jumpbox:
```bash
ssh-add ~/.ssh/my-key.pem
ssh -A ubuntu@<jumpbox-public-ip>
ssh ubuntu@<control-plane-private-ip>   # from inside the jumpbox
ssh ubuntu@<worker-private-ip>          # from inside the jumpbox
```

Next: [`../04-certificates.md`](../04-certificates.md) — from here on, every stage happens inside the terminal on these instances, identical whether you used the CLI or the console to get here.
