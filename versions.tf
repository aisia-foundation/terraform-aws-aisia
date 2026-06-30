###############################################################################
# terraform-aws-aisia — contraintes providers (module publiable, sans bloc provider).
# Le consumer configure `provider "aws" { region = "..." }` dans son root module.
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
  }
}
