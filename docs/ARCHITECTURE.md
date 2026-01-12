# Architecture – Yelb on AWS with Terraform

## Overview
- **VPC** with three public subnets: `public` (AZ A), `public2` (AZ B), `voter_public` (AZ A)
- **Internet Gateway** + shared **route table** with `0.0.0.0/0` to the IGW
- **Security groups** chained (ALB ▶ UI ▶ App ▶ DB/Redis; voter separate)
- **ALB (HTTP :80)** spans both public subnets and forwards to UI instances
- **Instances** bootstrap Docker and run Yelb containers (ui, appserver, db, redis)
- **Voter** periodically calls random endpoints via ALB

## Scaling & availability
- **UI instances** created via `count` (default: 4), **alternating** across `public`/`public2` using `element([...], count.index % 2)`
- **ALB** balances across healthy targets (health check `GET /`, 200–399)

## Security
- **ALB SG** allows HTTP `:80` from `0.0.0.0/0`
- **UI SG** allows traffic only from the ALB (port 80)
- **App/DB/Redis SGs** allow only the necessary east‑west traffic
- **SSH** is closed by default; can be opened via `var.ssh_cidr`

## Cloud‑Init & templatefile
- `infra/yelb-voter-cloudinit.yaml` rendered with `templatefile()`
- Shell variables escaped with `$$` so Terraform does not interpolate them

## Extensions
- **HTTPS**: ACM certificate + additional `aws_lb_listener` on port 443
- **Autoscaling**: Launch template + Auto Scaling Group; TG target type `instance` remains compatible
