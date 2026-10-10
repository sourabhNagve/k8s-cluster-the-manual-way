# Stage 3 — Launch Instances (AWS CLI)

> Prefer the AWS Console? See [`console.md`](./console.md).

| Node | Instance type | Subnet | Public IP |
|---|---|---|---|
| jumpbox | `t3.micro` | public | yes |
| control-plane | `t3.medium` | private | no |
| worker | `t3.medium` | private | no |

AMI: Ubuntu 22.04 LTS.

Launch via console or CLI (console is simpler for a one-off build — name the instances `jumpbox`, `control-plane`, `worker` so later steps are unambiguous).

## Disable source/destination check

Required later for the pod network routes (`11-pod-network-routes.md`) to actually work — AWS drops traffic by default where the packet's source/destination IP doesn't match the instance's own ENI, which is exactly what pod-to-pod traffic looks like.

```bash
aws ec2 modify-instance-attribute --instance-id <control-plane-instance-id> --no-source-dest-check
aws ec2 modify-instance-attribute --instance-id <worker-instance-id> --no-source-dest-check
```

## Access pattern

Use SSH agent forwarding so your private key never has to live on the jumpbox:
```bash
ssh-add ~/.ssh/my-key.pem
ssh -A ubuntu@<jumpbox-public-ip>
ssh ubuntu@<control-plane-private-ip>   # from inside the jumpbox
ssh ubuntu@<worker-private-ip>          # from inside the jumpbox
```

Next: [`04-certificates.md`](../04-certificates.md)
