# yelb-multi-ui-on-aws
Yelb UI running on AWS EC2 Instances + Extra EC2 Instance creating votes randomly

# Based on the content 
from mreferre (https://github.com/mreferre/yelb)
and
from Alex Goller (https://github.com/alexgoller/illumio-yelb)

# Yelb on AWS – Multi UI behind ALB (Terraform)

This repository deploys the **Yelb** demo application on **AWS EC2** using Terraform:
- **4 UI instances** behind an **Application Load Balancer (ALB)**
- **AZ spread** across **two public subnets**
- A **voter instance** in a **separate subnet** within the same VPC
- Appserver, Redis, and Postgres DB each as EC2 instances running Docker containers

## Prerequisites
- **Terraform** >= 1.5 (tested with 1.14.0)
- **AWS provider** >= 5.x (tested with 6.28.0)
- AWS account and valid **credentials** (e.g., via `aws configure`, `AWS_PROFILE`, `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`)

## Quickstart
```bash
# 1) Switch into the infrastructure directory
cd infra

# 2) Initialize
terraform init -reconfigure

# 3) Optional: format & validate
terraform fmt
terraform validate

# 4) Plan & apply
terraform plan
terraform apply
```

After a successful apply, fetch outputs:
```bash
terraform output alb_dns_name
terraform output ui_url
terraform output ui_public_ips
```

## Common variables
Key variables are documented in `infra/variables.tf`. Typical adjustments:
- `aws_region` (default: `eu-central-1`)
- `ui_count` (number of UI instances, default: `4`)
- `voter_subnet_cidr` (CIDR for voter subnet, default: `10.0.10.0/24`)
- `ssh_cidr` (optional SSH access; empty keeps SSH closed)

Example environment overrides:
```bash
export TF_VAR_ui_count=4
export TF_VAR_ssh_cidr="203.0.113.5/32"
```

## Notes
- The **ALB** is **public** and serves **HTTP (port 80)**. For **HTTPS**, add an ACM certificate and a `:443` listener.
- The voter Cloud‑Init uses `templatefile()`; shell variables in YAML are escaped with `$$` so Terraform does **not** interpolate them.

## Repository layout
```
yelb-multi-ui-aws-en/
├─ infra/                   # Terraform infrastructure
│  ├─ main.tf
│  ├─ variables.tf
│  ├─ outputs.tf
│  └─ yelb-voter-cloudinit.yaml
├─ docs/
│  └─ ARCHITECTURE.md       # Architecture & design choices
├─ .github/workflows/
│  └─ terraform.yml         # CI: fmt + validate (+ optional plan)
├─ .gitignore
├─ LICENSE (MIT)
├─ README.md
└─ Makefile                 # Convenience targets for init/plan/apply/destroy
```

## CI (optional)
The GitHub Actions workflow runs `terraform fmt -check` and `terraform validate`. For `plan` (optional), configure **GitHub Secrets**:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- optional: `AWS_REGION` (defaults to `eu-central-1`)
