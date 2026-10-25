###############################################################################
# AISIA — Terraform AWS — RDS Aurora PostgreSQL Serverless v2 (sprint v6.14.1)
#
# Cluster Aurora PostgreSQL serverless v2 utilise pour :
#   - ETL CrateDB → Postgres (compat protocole pour BI / analytics)
#   - Stockage backups longue duree (snapshots auto)
#   - Failover multi-AZ pour HA
#
# Master password genere par random_password puis stocke dans Secrets Manager.
###############################################################################

###############################################################################
# Subnet group dedie pour RDS (subnets prives uniquement)
###############################################################################
resource "aws_db_subnet_group" "aurora" {
  name        = "${var.cluster_name}-aurora-subnets"
  description = "AISIA Aurora subnet group (private subnets, 3 AZs)"
  subnet_ids  = module.vpc.private_subnets

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-aurora-subnets"
  })
}

###############################################################################
# Security group RDS — accepte 5432 depuis VPC CIDR
###############################################################################
resource "aws_security_group" "aurora" {
  name        = "${var.cluster_name}-aurora-sg"
  description = "AISIA Aurora cluster — accept Postgres from VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Aurora n'initie aucune connexion vers Internet : sortie limitée au VPC.
  egress {
    description = "Sortie limitee au VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-aurora-sg"
  })
}

###############################################################################
# Master password (genere puis stocke dans Secrets Manager)
###############################################################################
resource "random_password" "aurora_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
}

resource "aws_secretsmanager_secret" "aurora_master" {
  name        = "${var.cluster_name}/aurora/master"
  description = "AISIA Aurora master credentials"
  tags        = local.common_tags
}

resource "aws_secretsmanager_secret_version" "aurora_master" {
  secret_id = aws_secretsmanager_secret.aurora_master.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.aurora_master.result
    engine   = "postgres"
    host     = aws_rds_cluster.aurora.endpoint
    port     = aws_rds_cluster.aurora.port
    dbname   = var.db_name
  })
}

###############################################################################
# Clé KMS du stockage Aurora (CMK, rotation annuelle)
#
# Créée seulement si `db_kms_key_arn` est null. ATTENTION : changer la clé d'un
# cluster Aurora existant le RECRÉE (perte des données hors snapshot). Pour un
# cluster déjà chiffré par la clé gérée AWS `aws/rds`, passer son ARN dans
# `db_kms_key_arn` afin de conserver le cluster tel quel.
###############################################################################
resource "aws_kms_key" "aurora" {
  count = var.db_kms_key_arn == null ? 1 : 0

  description             = "AISIA Aurora storage encryption key (${var.cluster_name})"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-aurora-kms"
  })
}

resource "aws_kms_alias" "aurora" {
  count = var.db_kms_key_arn == null ? 1 : 0

  name          = "alias/${var.cluster_name}-aurora"
  target_key_id = aws_kms_key.aurora[0].key_id
}

locals {
  aurora_kms_key_arn = var.db_kms_key_arn != null ? var.db_kms_key_arn : aws_kms_key.aurora[0].arn
}

###############################################################################
# Aurora cluster (serverless v2)
###############################################################################
resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${var.cluster_name}-aurora"

  engine         = "aurora-postgresql"
  engine_mode    = "provisioned"
  engine_version = var.db_engine_version

  database_name   = var.db_name
  master_username = var.db_master_username
  master_password = random_password.aurora_master.result

  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  # Serverless v2 scaling
  serverlessv2_scaling_configuration {
    min_capacity = var.db_serverless_min_capacity
    max_capacity = var.db_serverless_max_capacity
  }

  # Backups
  backup_retention_period      = var.db_backup_retention_days
  preferred_backup_window      = "02:00-04:00"
  preferred_maintenance_window = "sun:04:30-sun:06:00"

  # Securite — chiffrement au repos par clé gérée par le client (CMK).
  # Clé dédiée créée par le module, sauf si `db_kms_key_arn` est fourni.
  storage_encrypted         = true
  kms_key_id                = local.aurora_kms_key_arn
  deletion_protection       = var.env == "prod" ? true : false
  skip_final_snapshot       = var.env != "prod"
  final_snapshot_identifier = var.env == "prod" ? "${var.cluster_name}-aurora-final-${formatdate("YYYYMMDD-hhmm", timestamp())}" : null

  # Logs
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # IAM database authentication (pour rotation Vault)
  iam_database_authentication_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-aurora"
  })

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

###############################################################################
# Cluster instances (1 writer + 1 reader pour HA)
###############################################################################
resource "aws_rds_cluster_instance" "aurora" {
  count = 2

  identifier         = "${var.cluster_name}-aurora-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.aurora.id

  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.aurora.engine
  engine_version       = aws_rds_cluster.aurora.engine_version
  db_subnet_group_name = aws_db_subnet_group.aurora.name

  publicly_accessible = false
  apply_immediately   = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-aurora-instance-${count.index + 1}"
    Role = count.index == 0 ? "writer" : "reader"
  })
}
