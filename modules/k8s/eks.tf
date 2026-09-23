###############################################################################
# AISIA — Terraform AWS — EKS managed cluster (sprint v6.14.1)
#
# Cluster EKS managed avec :
#   - Control plane public + prive
#   - Managed node group t3.large × cluster_size
#   - OIDC provider pour IRSA (IAM Roles for Service Accounts)
#   - Add-ons : VPC CNI, kube-proxy, CoreDNS, EBS CSI driver
#   - Logging CloudWatch (api, audit, authenticator)
###############################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.13"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Logs CloudWatch
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # OIDC provider auto-cree (utilise pour IRSA)
  enable_irsa = true

  ###############################################################################
  # Managed node group
  ###############################################################################
  eks_managed_node_group_defaults = {
    ami_type       = "AL2023_x86_64_STANDARD"
    instance_types = [var.instance_flavor]
    disk_size      = var.node_disk_size_gb

    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }

  eks_managed_node_groups = {
    aisia_workers = {
      name           = "${var.cluster_name}-workers"
      instance_types = [var.instance_flavor]

      min_size     = var.node_count
      max_size     = var.node_count * 2
      desired_size = var.node_count

      capacity_type = "ON_DEMAND"

      labels = {
        Project     = "AISIA"
        Environment = var.env
        NodeGroup   = "workers"
      }

      tags = local.common_tags
    }
  }

  tags = local.common_tags
}

###############################################################################
# IRSA role example — service account 'aisia-api' peut lire Secrets Manager
###############################################################################
data "aws_iam_policy_document" "aisia_api_secrets_access" {
  statement {
    sid    = "ReadProviderSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [for s in aws_secretsmanager_secret.providers : s.arn]
  }
}

resource "aws_iam_policy" "aisia_api_secrets" {
  name        = "${var.cluster_name}-aisia-api-secrets"
  description = "Allow aisia-api SA to read provider secrets from Secrets Manager"
  policy      = data.aws_iam_policy_document.aisia_api_secrets_access.json

  tags = local.common_tags
}

module "aisia_api_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name = "${var.cluster_name}-aisia-api-irsa"

  role_policy_arns = {
    secrets = aws_iam_policy.aisia_api_secrets.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["aisia:aisia-api"]
    }
  }

  tags = local.common_tags
}
