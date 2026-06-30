# Changelog — terraform-aws-aisia

Format : [Keep a Changelog](https://keepachangelog.com/) · Versioning : SemVer.

## [1.0.0] — 2026-06-29

### Added
- Module initial publiable (HCP private registry) : substrat Docker Swarm sur AWS EC2.
- **Réseau** : VPC /16 + subnet public mono-AZ + Internet Gateway + route table.
- **Compute** : 1 instance EC2 manager (docker swarm init via cloud-init) + N workers
  (docker installé, join post-apply via token sur le manager).
- **Sécurité** : Security Group Swarm (TCP 2377, TCP/UDP 7946, UDP 4789) + HTTPS/HTTP +
  SSH restreint au CIDR `ssh_allowed_cidr`. EBS root chiffré (gp3).
- **Parité dual-substrate** : pendant AWS Swarm du module `terraform-aws-aisia` EKS
  (substrat K8s). Parité fonctionnelle garantie par le contrat normalisé v6.9.61.
- Variables tier-aware, `image_registry`/`image_tag`, `gpu_enabled` (signale le besoin
  GPU — utiliser un `instance_flavor` GPU comme `p3.2xlarge` ou `g5.xlarge`).
- Outputs normalisés : `manager_ip`, `manager_private_ip`, `worker_ips`, `vpc_id`,
  `swarm_join_command`, `next_steps`.
- README (Inputs/Outputs/Usage), LICENSE MPL-2.0, `versions.tf` (TF >= 1.7, aws ~> 5.0).
- `examples/basic` : usage minimal validable (`tofu validate`).
