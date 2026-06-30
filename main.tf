###############################################################################
# terraform-aws-aisia — substrat Docker Swarm sur AWS EC2.
#
#   ┌──────────────────────────────────────────────────────────────────────┐
#   │ VPC /16 + subnet public mono-AZ + IGW + Route table                  │
#   │ Security Group : SSH + HTTP/HTTPS + Swarm (2377 / 7946 / 4789)      │
#   │ 1 instance EC2 manager (docker swarm init via cloud-init)            │
#   │ N instances EC2 workers (docker installé, join post-apply)           │
#   └──────────────────────────────────────────────────────────────────────┘
#
# Usage : chaîner avec terraform-aisia-cluster (source K8s) OU déployer
# la stack AISIA via `docker stack deploy` sur le manager (substrat Swarm).
#
# Worker join : récupérer le token sur le manager après apply :
#   ssh ubuntu@<manager_ip> 'sudo cat /tmp/worker-token'
###############################################################################

locals {
  name = "${var.cluster_name}-${var.org_id}-${var.service_key}"

  common_tags = {
    aisia_org     = var.org_id
    aisia_service = var.service_key
    Project       = "AISIA"
    Environment   = var.env
    image_tag     = var.image_tag
    ManagedBy     = "terraform"
  }

  user_data_manager = <<-EOT
    #cloud-config
    package_update: true
    packages:
      - docker.io
    runcmd:
      - systemctl enable --now docker
      - usermod -aG docker ubuntu
      - PRIV_IP=$(hostname -I | awk '{print $1}') && docker swarm init --advertise-addr "$PRIV_IP"
      - docker swarm join-token -q worker > /tmp/worker-token
      # AISIA image : ${var.image_registry}/aisia:${var.image_tag}
      # TODO : publier worker-token dans S3 (SSE-KMS) pour auto-join workers
  EOT

  user_data_worker = <<-EOT
    #cloud-config
    package_update: true
    packages:
      - docker.io
    runcmd:
      - systemctl enable --now docker
      - usermod -aG docker ubuntu
      # TODO : fetch worker-token (S3/SSM) puis :
      # docker swarm join --token <TOKEN> ${aws_instance.manager.private_ip}:2377
  EOT
}

###############################################################################
# AMI Ubuntu 24.04 LTS (Canonical)
###############################################################################
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

###############################################################################
# VPC + Subnet public + IGW + Route table
###############################################################################
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, { Name = "${local.name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${local.name}-igw" })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet_cidr
  availability_zone       = var.availability_zone != "" ? var.availability_zone : data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, { Name = "${local.name}-public" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, { Name = "${local.name}-rt-public" })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

###############################################################################
# Security Group — Swarm + HTTP/HTTPS + SSH
###############################################################################
resource "aws_security_group" "swarm" {
  name        = "${local.name}-sg"
  description = "AISIA Swarm cluster"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "HTTP (Traefik)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS (Traefik)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Swarm management plane"
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Swarm gossip TCP"
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Swarm gossip UDP"
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Swarm overlay VXLAN"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Tout sortant"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name}-sg" })
}

###############################################################################
# Key pair SSH (optionnel)
###############################################################################
resource "aws_key_pair" "this" {
  count      = var.ssh_public_key != "" ? 1 : 0
  key_name   = "${local.name}-key"
  public_key = var.ssh_public_key

  tags = local.common_tags
}

###############################################################################
# Instance manager (docker swarm init)
###############################################################################
resource "aws_instance" "manager" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_flavor
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.swarm.id]
  key_name                    = var.ssh_public_key != "" ? aws_key_pair.this[0].key_name : null
  associate_public_ip_address = true
  user_data                   = local.user_data_manager

  root_block_device {
    volume_size = var.node_disk_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name}-manager"
    aisia_role = "manager"
  })
}

###############################################################################
# Instances workers (docker installé, join post-apply)
###############################################################################
resource "aws_instance" "worker" {
  count                       = var.node_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_flavor
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.swarm.id]
  key_name                    = var.ssh_public_key != "" ? aws_key_pair.this[0].key_name : null
  associate_public_ip_address = true
  user_data                   = local.user_data_worker

  depends_on = [aws_instance.manager]

  root_block_device {
    volume_size = var.node_disk_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name}-worker-${count.index + 1}"
    aisia_role = "worker"
  })
}
