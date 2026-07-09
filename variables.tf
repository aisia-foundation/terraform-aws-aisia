###############################################################################
# terraform-aws-aisia — variables d'entrée.
# Substrat Docker Swarm sur AWS EC2. Contrat normalisé v6.9.61.
#
# Auth AWS : le consumer configure `provider "aws" { region = var.region }`
# dans son root module. Les credentials (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
# / profil ~/.aws/credentials) ne transitent pas par les variables du module.
###############################################################################

# ── Contrat normalisé (commun à tous les clouds × substrats) ───────────────
variable "org_id" {
  description = "Identifiant de l'organisation AISIA (tenant)."
  type        = string
}

variable "service_key" {
  description = "Brique déployée (C1..C11)."
  type        = string
}

variable "runtime_kind" {
  description = "edge | compute | compute-gpu | data | ops | security."
  type        = string
  default     = "compute"
}

variable "substrate" {
  description = "Substrat cible. Ce module provisionne le substrat 'swarm'."
  type        = string
  default     = "swarm"
}

variable "profile" {
  description = "Profil de dimensionnement (S | M | L | XL)."
  type        = string
  default     = "S"
}

variable "node_count" {
  description = "Nombre de workers Swarm (le manager est en plus)."
  type        = number
  default     = 1
}

variable "instance_flavor" {
  description = "Type d'instance EC2 des nœuds Swarm (manager + workers). Ex : t3.large, m6i.xlarge."
  type        = string
  default     = "t3.large"
}

variable "image_registry" {
  description = "Registry des images AISIA."
  type        = string
  default     = "registry.aisia.fr"
}

variable "image_tag" {
  description = "Tag d'image AISIA à déployer (ex. v6.9.61)."
  type        = string
  default     = "v6.9.98"
}

variable "domain" {
  description = "Domaine custom de l'org (vide = *.aisia.fr)."
  type        = string
  default     = ""
}

variable "tier" {
  description = "Offre tarifaire AISIA (saas | baas | paas)."
  type        = string
  default     = "saas"
  validation {
    condition     = contains(["saas", "baas", "paas"], var.tier)
    error_message = "tier doit etre 'saas', 'baas' ou 'paas'."
  }
}

variable "gpu_enabled" {
  description = "Signal GPU actif. Pour GPU sur Swarm, utiliser un instance_flavor GPU (ex. g5.xlarge, p3.2xlarge)."
  type        = bool
  default     = false
}

# ── Spécifiques AWS Swarm ──────────────────────────────────────────────────
variable "region" {
  description = "Région AWS (eu-west-3 = Paris pour conformité RGPD)."
  type        = string
  default     = "eu-west-3"
}

variable "env" {
  description = "Environnement (prod | staging | dev). Utilisé pour le tagging AWS."
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["prod", "staging", "dev"], var.env)
    error_message = "env doit etre 'prod', 'staging' ou 'dev'."
  }
}

variable "cluster_name" {
  description = "Nom logique du cluster Swarm (préfixe des ressources AWS)."
  type        = string
  default     = "aisia-swarm"
}

variable "vpc_cidr" {
  description = "CIDR du VPC (RFC1918)."
  type        = string
  default     = "10.40.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR du subnet public hébergeant les nœuds Swarm."
  type        = string
  default     = "10.40.1.0/24"
}

variable "availability_zone" {
  description = "AZ cible du subnet (vide = première AZ disponible de la région)."
  type        = string
  default     = ""
}

variable "node_disk_size_gb" {
  description = "Taille du disque EBS root des nœuds (GiB)."
  type        = number
  default     = 50
}

variable "ssh_public_key" {
  description = "Clé publique SSH (contenu OpenSSH). Vide = pas de key pair (accès SSM uniquement)."
  type        = string
  default     = ""
}

variable "ssh_allowed_cidr" {
  description = "CIDR autorisé pour SSH. Restreindre à l'IP fixe admin en production."
  type        = string
  default     = "0.0.0.0/0"
}
