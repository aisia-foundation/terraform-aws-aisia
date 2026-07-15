###############################################################################
# Exemple minimal — terraform-aws-aisia (substrat Docker Swarm sur EC2)
#
# Prérequis : credentials AWS via env vars ou ~/.aws/credentials.
#   export AWS_ACCESS_KEY_ID=...
#   export AWS_SECRET_ACCESS_KEY=...
#   export AWS_DEFAULT_REGION=eu-west-3
###############################################################################

terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
}

###############################################################################
# Substrat Swarm — 1 manager + 2 workers EC2
###############################################################################
module "aisia_aws_swarm" {
  # source = "app.terraform.io/AISIA/aisia/aws"
  # version = "1.0.0"
  source = "../../"

  org_id      = "acme"
  service_key = "C1"
  image_tag   = "v6.12.41"
  tier        = "saas"

  region          = "eu-west-3"
  node_count      = 2
  instance_flavor = "t3.large"

  # Restreindre SSH à votre IP en production (ici ouvert pour le test).
  ssh_allowed_cidr = "0.0.0.0/0"
  # ssh_public_key = file("~/.ssh/id_rsa.pub")
}

output "manager_ip" {
  value = module.aisia_aws_swarm.manager_ip
}

output "worker_ips" {
  value = module.aisia_aws_swarm.worker_ips
}

output "next_steps" {
  value = module.aisia_aws_swarm.next_steps
}
