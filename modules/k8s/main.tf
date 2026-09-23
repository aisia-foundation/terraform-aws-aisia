###############################################################################
# AISIA — Terraform AWS — VPC + Networking (sprint v6.13.18)
#
#   ┌──────────────────────────────────────────────────────────────────┐
#   │ VPC /16  +  3 subnets publics + 3 subnets prives (multi-AZ)      │
#   │ IGW + NAT gateway(s) + Route tables                              │
#   │ Module officiel terraform-aws-modules/vpc/aws                    │
#   └──────────────────────────────────────────────────────────────────┘
###############################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  common_tags = {
    Project     = "AISIA"
    Environment = var.env
    Sprint      = "v6.13.18"
  }
}

###############################################################################
# VPC + Subnets + IGW + NAT
###############################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true
  flow_log_max_aggregation_interval    = 60

  # Tags requis par EKS pour decouvrir les subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = local.common_tags
}

###############################################################################
# Security Group commun (services internes — RDS, EKS pods)
###############################################################################
resource "aws_security_group" "internal" {
  name        = "${var.cluster_name}-internal"
  description = "AISIA internal services (RDS, EKS pods, Vault)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "PostgreSQL (Aurora + CrateDB compat)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "HTTPS interne (services to services)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Vault HA Raft (8200/8201)"
    from_port   = 8200
    to_port     = 8201
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-internal-sg"
  })
}
