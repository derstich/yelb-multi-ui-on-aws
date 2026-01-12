
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "tls_private_key" "generated" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated" {
  key_name   = var.generated_key_name
  public_key = tls_private_key.generated.public_key_openssh
  tags       = { Name = "${var.project_name}-keypair", app = "yelb" }
}

resource "local_file" "pem" {
  filename        = var.pem_output_path
  content         = tls_private_key.generated.private_key_pem
  file_permission = "0400"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project_name}-vpc", app = "yelb" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw", app = "yelb" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags                    = { Name = "${var.project_name}-public", app = "yelb" }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]
  tags                    = { Name = "${var.project_name}-public-2", app = "yelb" }
}

resource "aws_subnet" "voter_public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.voter_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags                    = { Name = "${var.project_name}-subnet-voter-public", app = "yelb" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project_name}-rt-public", app = "yelb" }
}

resource "aws_route_table_association" "public_assoc" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public.id
}

resource "aws_route_table_association" "public_assoc_2" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public2.id
}

resource "aws_route_table_association" "voter_public_assoc" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.voter_public.id
}

resource "aws_security_group" "sg_alb" {
  name        = "${var.project_name}-sg-alb"
  description = "ALB ingress HTTP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP to ALB :80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg-alb", app = "yelb" }
}

resource "aws_security_group" "sg_ui" {
  name        = "${var.project_name}-sg-ui"
  description = "HTTP to UI (nur vom ALB)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "ALB to UI :80"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_alb.id]
  }

  dynamic "ingress" {
    for_each = var.ssh_cidr == "" ? [] : [var.ssh_cidr]
    content {
      description = "SSH to UI :22"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg-ui", app = "yelb" }
}

resource "aws_security_group" "sg_app" {
  name        = "${var.project_name}-sg-app"
  vpc_id      = aws_vpc.main.id
  description = "Appserver traffic"

  ingress {
    description     = "UI to App :4567"
    from_port       = 4567
    to_port         = 4567
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ui.id]
  }

  dynamic "ingress" {
    for_each = var.ssh_cidr == "" ? [] : [var.ssh_cidr]
    content {
      description = "SSH to App :22"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg-app", app = "yelb" }
}

resource "aws_security_group" "sg_db" {
  name        = "${var.project_name}-sg-db"
  vpc_id      = aws_vpc.main.id
  description = "Database access"

  ingress {
    description     = "App to DB :5432"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_app.id]
  }

  dynamic "ingress" {
    for_each = var.ssh_cidr == "" ? [] : [var.ssh_cidr]
    content {
      description = "SSH to DB :22"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg-db", app = "yelb" }
}

resource "aws_security_group" "sg_redis" {
  name        = "${var.project_name}-sg-redis"
  vpc_id      = aws_vpc.main.id
  description = "Redis access"

  ingress {
    description     = "App to Redis :6379"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_app.id]
  }

  dynamic "ingress" {
    for_each = var.ssh_cidr == "" ? [] : [var.ssh_cidr]
    content {
      description = "SSH to Redis :22"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg-redis", app = "yelb" }
}

resource "aws_security_group" "sg_voter" {
  name        = "${var.project_name}-sg-voter"
  vpc_id      = aws_vpc.main.id
  description = "Voter instance security group"

  dynamic "ingress" {
    for_each = var.ssh_cidr == "" ? [] : [var.ssh_cidr]
    content {
      description = "SSH to Voter :22"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg-voter", app = "yelb" }
}

data "aws_ami" "amzn2" {
  most_recent = true
  owners      = ["137112412989"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

locals {
  ui_image    = "derstich/yelb-ui:latest"
  app_image   = "derstich/yelb-appserver:latest"
  db_image    = "derstich/yelb-db:latest"
  redis_image = "derstich/redis-server:latest"
}

locals {
  docker_base = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    yum update -y
    amazon-linux-extras install docker -y || true
    yum install -y docker || true
    systemctl enable docker
    systemctl start docker
    docker network create yelb-net || true
  EOT

  ghcr_login_script = <<-EOT
    echo "${var.ghcr_token}" | docker login ghcr.io -u "${var.ghcr_username}" --password-stdin
  EOT

  ghcr_login = (
    var.use_ghcr_illumio_images && var.ghcr_username != "" && var.ghcr_token != ""
  ) ? local.ghcr_login_script : ""
}

resource "aws_instance" "db" {
  ami                    = data.aws_ami.amzn2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.sg_db.id]
  key_name               = aws_key_pair.generated.key_name

  user_data = <<-EOT
    ${local.docker_base}
    ${local.ghcr_login}
    docker run -d --restart unless-stopped --name yelb-db --network yelb-net -p 5432:5432 ${local.db_image}
  EOT

  tags = { Name = "${var.project_name}-db", app = "yelb", role = "db" }
}

resource "aws_instance" "redis" {
  ami                    = data.aws_ami.amzn2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.sg_redis.id]
  key_name               = aws_key_pair.generated.key_name

  user_data = <<-EOT
    ${local.docker_base}
    ${local.ghcr_login}
    docker run -d --restart unless-stopped --name redis-server --network yelb-net -p 6379:6379 ${local.redis_image}
  EOT

  tags = { Name = "${var.project_name}-redis", app = "yelb", role = "db" }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amzn2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.sg_app.id]
  key_name               = aws_key_pair.generated.key_name
  depends_on             = [aws_instance.db, aws_instance.redis]

  user_data = <<-EOT
    ${local.docker_base}
    ${local.ghcr_login}
    docker run -d --restart unless-stopped --name yelb-appserver --network yelb-net \
      --add-host yelb-db:${aws_instance.db.private_ip} \
      --add-host redis-server:${aws_instance.redis.private_ip} \
      -p 4567:4567 \
      -e YELB_DB_HOST="${aws_instance.db.private_ip}" -e YELB_DB_PORT="5432" \
      -e REDIS_SERVER="${aws_instance.redis.private_ip}" -e REDIS_SERVER_PORT="6379" \
      ${local.app_image}
  EOT

  tags = { Name = "${var.project_name}-app", app = "yelb", role = "app" }
}

resource "aws_instance" "ui" {
  count                  = var.ui_count
  ami                    = data.aws_ami.amzn2.id
  instance_type          = var.instance_type
  subnet_id              = element([aws_subnet.public.id, aws_subnet.public2.id], count.index % 2)
  vpc_security_group_ids = [aws_security_group.sg_ui.id]
  key_name               = aws_key_pair.generated.key_name
  depends_on             = [aws_instance.app]

  user_data = <<-EOT
    ${local.docker_base}
    ${local.ghcr_login}
    docker run -d --restart unless-stopped --name yelb-ui --network yelb-net \
      --add-host yelb-appserver:${aws_instance.app.private_ip} \
      -e YELB_APPSERVER_ENDPOINT="http://yelb-appserver:4567" \
      -p 80:80 ${local.ui_image}
  EOT

  tags = {
    Name = "${var.project_name}-ui-${count.index + 1}"
    app  = "yelb"
    role = "web"
  }
}

resource "aws_instance" "voter" {
  ami                    = data.aws_ami.amzn2.id
  instance_type          = var.voter_instance_type
  subnet_id              = aws_subnet.voter_public.id
  vpc_security_group_ids = [aws_security_group.sg_voter.id]
  key_name               = aws_key_pair.generated.key_name
  depends_on             = [aws_lb.ui]

  user_data = templatefile("${path.module}/yelb-voter-cloudinit.yaml", {
    alb_url  = "http://${aws_lb.ui.dns_name}"
    interval = var.voter_interval_seconds
  })

  tags = { Name = "${var.project_name}-voter", app = "yelb", role = "voter" }
}

resource "aws_lb" "ui" {
  name                       = "${var.project_name}-alb"
  load_balancer_type         = "application"
  subnets                    = [aws_subnet.public.id, aws_subnet.public2.id]
  security_groups            = [aws_security_group.sg_alb.id]
  enable_deletion_protection = false
  tags                       = { Name = "${var.project_name}-alb", app = "yelb" }
}

resource "aws_lb_target_group" "ui_tg" {
  name        = "${var.project_name}-tg-ui"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "${var.project_name}-tg-ui", app = "yelb" }
}

resource "aws_lb_target_group_attachment" "ui_attach" {
  count            = var.ui_count
  target_group_arn = aws_lb_target_group.ui_tg.arn
  target_id        = aws_instance.ui[count.index].id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ui.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ui_tg.arn
  }
}
