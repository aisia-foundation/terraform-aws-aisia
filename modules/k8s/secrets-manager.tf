###############################################################################
# AISIA — Terraform AWS — Secrets Manager (sprint v6.14.1)
#
# Cree N secrets vides (placeholders) pour cles API providers.
# Les valeurs reelles doivent etre injectees POST-APPLY :
#
#   aws secretsmanager put-secret-value \
#     --secret-id aisia-eks/providers/anthropic \
#     --secret-string '{"api_key":"sk-ant-..."}'
#
# Ou via la GUI admin AISIA (onglet "Credentials" → "AWS Secrets Manager").
#
# IRSA permet a la SA 'aisia-api' de lire ces secrets sans hardcoder les
# credentials AWS dans les pods (voir eks.tf module aisia_api_irsa_role).
###############################################################################

###############################################################################
# KMS key dediee aux secrets AISIA (rotation automatique annuelle)
###############################################################################
resource "aws_kms_key" "secrets" {
    description             = "AISIA Secrets Manager encryption key (sprint v6.14.1)"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-secrets-kms"
  })
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.cluster_name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

###############################################################################
# Secrets providers (placeholders vides — fill post-apply)
###############################################################################
resource "aws_secretsmanager_secret" "providers" {
  for_each = toset(var.provider_secret_names)

  name        = "${var.cluster_name}/providers/${each.key}"
  description = "AISIA provider API key — ${each.key}"
  kms_key_id  = aws_kms_key.secrets.arn

  recovery_window_in_days = var.env == "prod" ? 30 : 0

  tags = merge(local.common_tags, {
    Name     = "${var.cluster_name}-provider-${each.key}"
    Provider = each.key
  })
}

###############################################################################
# Initial empty placeholder values (a remplir post-apply)
###############################################################################
resource "aws_secretsmanager_secret_version" "providers_placeholder" {
  for_each = aws_secretsmanager_secret.providers

  secret_id = each.value.id
  secret_string = jsonencode({
    api_key    = "PLACEHOLDER_REPLACE_AFTER_APPLY"
    created_at = timestamp()
    note       = "Replace via: aws secretsmanager put-secret-value --secret-id ${each.value.name} --secret-string '{\"api_key\":\"REAL_KEY\"}'"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

###############################################################################
# Secret bundle global AISIA (config metadata, NON sensible)
###############################################################################
resource "aws_secretsmanager_secret" "aisia_config" {
  name        = "${var.cluster_name}/config/global"
  description = "AISIA global configuration metadata"
  kms_key_id  = aws_kms_key.secrets.arn

  recovery_window_in_days = var.env == "prod" ? 30 : 0

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "aisia_config" {
  secret_id = aws_secretsmanager_secret.aisia_config.id
  secret_string = jsonencode({
    cluster_name    = var.cluster_name
    env             = var.env
    aws_region      = var.region
    aurora_endpoint = aws_rds_cluster.aurora.endpoint
    aurora_port     = aws_rds_cluster.aurora.port
    aurora_db_name  = var.db_name
    eks_endpoint    = module.eks.cluster_endpoint
    sprint          = "v6.14.1"
  })
}
