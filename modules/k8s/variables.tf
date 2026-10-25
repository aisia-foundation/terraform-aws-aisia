###############################################################################
# AISIA — Terraform AWS variables
#
# Contrat NORMALISÉ v6.14.1 : les 13 variables communes ci-dessous sont
# identiques (noms + types + defaults cloud-agnostiques) à tous les clouds ×
# substrats (référence : infra/terraform/gcp/{k8s,swarm}). Les defaults
# spécifiques au cloud (region, instance_flavor, substrate) sont adaptés à AWS.
# Substrat AWS = EKS managed (k8s).
###############################################################################

# ── Contrat normalisé (commun à tous les clouds) ───────────────────────────
variable "org_id" {
  description = "Identifiant de l'organisation AISIA (tenant)."
  type        = string
}

variable "service_key" {
  description = "Brique déployée (C1..C11, cf. aisia_deployable_services)."
  type        = string
}

variable "runtime_kind" {
  description = "edge|compute|compute-gpu|data|ops|security."
  type        = string
  default     = "compute"
}

variable "substrate" {
  description = "Substrat cible (k8s|swarm). Ici : k8s (EKS)."
  type        = string
  default     = "k8s"
}

variable "profile" {
  description = "Profil de dimensionnement (S|M|L|XL)."
  type        = string
  default     = "S"
}

variable "region" {
  description = "Région AWS (eu-west-3 = Paris pour conformité RGPD)."
  type        = string
  default     = "eu-west-3"
}

variable "node_count" {
  description = "Nombre de nœuds workers EKS (mappé depuis le profil)."
  type        = number
  default     = 1
}

variable "instance_flavor" {
  description = "Type d'instance EC2 des worker nodes EKS (ex: t3.large)."
  type        = string
  default     = "t3.large"
}

variable "image_registry" {
  description = "Registry des images AISIA."
  type        = string
  default     = "registry.aisia.fr"
}

variable "image_tag" {
  description = "Tag d'image AISIA à déployer."
  type        = string
  default     = "v6.14.22"
}

variable "domain" {
  description = "Domaine custom de l'org (vide = *.aisia.fr)."
  type        = string
  default     = ""
}

variable "tier" {
  description = "Offre (saas|baas|paas)."
  type        = string
  default     = "saas"
}

variable "gpu_enabled" {
  description = "Provisionner un pool GPU (runtime compute-gpu / inférence C4)."
  type        = bool
  default     = false
}

# ── Spécifiques AWS ────────────────────────────────────────────────────────
variable "env" {
  description = "Environnement (prod, staging, dev)."
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["prod", "staging", "dev"], var.env)
    error_message = "env doit etre 'prod', 'staging' ou 'dev'."
  }
}

###############################################################################
# Networking
###############################################################################
variable "vpc_cidr" {
  description = "CIDR du VPC (RFC1918)."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs des 3 subnets publics (1 par AZ)."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs des 3 subnets prives (1 par AZ)."
  type        = list(string)
  default     = ["10.20.11.0/24", "10.20.12.0/24", "10.20.13.0/24"]
}

variable "single_nat_gateway" {
  description = "Mutualiser un seul NAT gateway (cost-saving) ou 1 par AZ (HA)."
  type        = bool
  default     = false
}

###############################################################################
# EKS
###############################################################################
variable "cluster_name" {
  description = "Nom du cluster EKS."
  type        = string
  default     = "aisia-eks"
}

variable "kubernetes_version" {
  description = "Version Kubernetes EKS."
  type        = string
  default     = "1.30"
}

variable "node_disk_size_gb" {
  description = "Taille disque EBS root des worker nodes (GiB)."
  type        = number
  default     = 100
}

variable "cluster_endpoint_public_access" {
  description = "Expose l'API Kubernetes EKS sur Internet. Faux par défaut (endpoint privé, joignable depuis le VPC, un VPN ou un bastion). Vrai exige cluster_endpoint_public_access_cidrs."
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR autorisés sur l'endpoint public EKS (IP d'administration, runner CI). Ignoré si l'endpoint public est désactivé ; 0.0.0.0/0 refusé."
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for c in var.cluster_endpoint_public_access_cidrs : can(cidrhost(c, 0)) && !endswith(c, "/0")
    ])
    error_message = "cluster_endpoint_public_access_cidrs : CIDR valides uniquement, jamais 0.0.0.0/0 ni ::/0."
  }
}

variable "node_security_group_enable_recommended_rules" {
  description = "Conserve les règles recommandées du module EKS amont pour le groupe de sécurité des nœuds, dont la sortie complète via NAT. Mettre false pour n'appliquer que node_security_group_additional_rules."
  type        = bool
  default     = true
}

variable "node_security_group_additional_rules" {
  description = "Règles supplémentaires du groupe de sécurité des nœuds EKS (format du module terraform-aws-modules/eks). Sert à décrire une sortie restreinte quand les règles recommandées sont désactivées."
  type        = any
  default     = {}
}

###############################################################################
# RDS Aurora PostgreSQL serverless v2
###############################################################################
variable "db_name" {
  description = "Nom de la base AISIA (ETL CrateDB compat PostgreSQL)."
  type        = string
  default     = "aisia"
}

variable "db_master_username" {
  description = "Username master Aurora (mot de passe genere automatiquement)."
  type        = string
  default     = "aisia_admin"
}

variable "db_engine_version" {
  description = "Version Aurora PostgreSQL."
  type        = string
  default     = "16.2"
}

variable "db_serverless_min_capacity" {
  description = "Capacite minimum ACU (Aurora Serverless v2)."
  type        = number
  default     = 0.5
}

variable "db_serverless_max_capacity" {
  description = "Capacite maximum ACU (Aurora Serverless v2)."
  type        = number
  default     = 8.0
}

variable "db_backup_retention_days" {
  description = "Retention backups Aurora (jours)."
  type        = number
  default     = 14
}

variable "db_kms_key_arn" {
  description = "ARN d'une clé KMS existante pour chiffrer Aurora. Null = le module crée une clé dédiée avec rotation. Changer la clé d'un cluster existant le recrée : pour un cluster déjà chiffré par aws/rds, passer l'ARN de cette clé."
  type        = string
  default     = null
}

###############################################################################
# Secrets Manager — providers API keys
###############################################################################
variable "provider_secret_names" {
  description = "Liste des noms providers a creer dans Secrets Manager."
  type        = list(string)
  default = [
    "anthropic",
    "openai",
    "mistral",
    "groq",
    "google-gemini",
    "cohere",
    "perplexity",
    "deepseek",
    "stripe",
    "ovh",
    "huggingface",
  ]
}
