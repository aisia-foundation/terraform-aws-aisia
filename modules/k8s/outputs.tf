###############################################################################
# AISIA — Terraform AWS outputs (sprint v6.13.18)
###############################################################################

###############################################################################
# Contrat de sortie normalisé (commun substrat k8s — cf. gcp/k8s)
# cluster_name / cluster_endpoint / kubeconfig_command sont définis plus bas
# (section EKS).
###############################################################################
output "region" {
  description = "Région AWS du déploiement."
  value       = var.region
}

output "gpu_pool_enabled" {
  description = "Un pool GPU a-t-il été provisionné ?"
  value       = var.gpu_enabled
}

###############################################################################
# Networking
###############################################################################
output "vpc_id" {
  description = "ID du VPC AISIA"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR du VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs des subnets publics (3 AZs)"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs des subnets prives (3 AZs)"
  value       = module.vpc.private_subnets
}

output "availability_zones" {
  description = "AZs utilisees"
  value       = local.azs
}

###############################################################################
# EKS
###############################################################################
output "cluster_endpoint" {
  description = "Endpoint API du cluster EKS"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "cluster_name" {
  description = "Nom du cluster EKS"
  value       = module.eks.cluster_name
}

output "cluster_version" {
  description = "Version Kubernetes du cluster"
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "Security group attache au control plane EKS"
  value       = module.eks.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "Issuer OIDC du cluster (pour IRSA)"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_certificate_authority_data" {
  description = "CA certificate base64 du cluster (pour kubeconfig)"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Commande pour generer le kubeconfig local"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "aisia_api_irsa_role_arn" {
  description = "ARN du role IRSA pour la SA 'aisia-api'"
  value       = module.aisia_api_irsa_role.iam_role_arn
}

###############################################################################
# RDS Aurora
###############################################################################
output "db_endpoint" {
  description = "Endpoint writer Aurora"
  value       = aws_rds_cluster.aurora.endpoint
}

output "db_reader_endpoint" {
  description = "Endpoint reader Aurora (lecture seule, load-balance)"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "db_port" {
  description = "Port Aurora"
  value       = aws_rds_cluster.aurora.port
}

output "db_name" {
  description = "Nom de la base"
  value       = aws_rds_cluster.aurora.database_name
}

output "db_master_secret_arn" {
  description = "ARN du secret contenant les credentials master Aurora"
  value       = aws_secretsmanager_secret.aurora_master.arn
}

###############################################################################
# Secrets Manager
###############################################################################
output "secrets_arn" {
  description = "Map nom_provider → ARN du secret"
  value       = { for k, v in aws_secretsmanager_secret.providers : k => v.arn }
}

output "secrets_kms_key_arn" {
  description = "ARN de la KMS key chiffrant les secrets AISIA"
  value       = aws_kms_key.secrets.arn
}

output "aisia_config_secret_arn" {
  description = "ARN du secret de config globale AISIA"
  value       = aws_secretsmanager_secret.aisia_config.arn
}

###############################################################################
# Recap
###############################################################################
output "deployment_summary" {
  description = "Recap deploiement"
  value = {
    cluster_name  = module.eks.cluster_name
    region        = var.region
    env           = var.env
    eks_endpoint  = module.eks.cluster_endpoint
    db_endpoint   = aws_rds_cluster.aurora.endpoint
    vpc_id        = module.vpc.vpc_id
    secrets_count = length(aws_secretsmanager_secret.providers)
    sprint        = "v6.13.18"
  }
}
