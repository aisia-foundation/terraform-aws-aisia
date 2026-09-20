###############################################################################
# AISIA — Terraform AWS infrastructure (sprint v6.13.16)
#
# Versions pinning : Terraform >= 1.7, AWS provider ~> 5.0
###############################################################################

terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Backend remote (a activer apres bootstrap S3 + DynamoDB lock)
  # backend "s3" {
  #   bucket         = "aisia-terraform-state"
  #   key            = "aws/prod/terraform.tfstate"
  #   region         = "eu-west-3"
  #   encrypt        = true
  #   dynamodb_table = "aisia-terraform-locks"
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "AISIA"
      Environment = var.env
      ManagedBy   = "Terraform"
      Sprint      = "v6.13.16"
      Owner       = "sebastien.lambert"
    }
  }
}
