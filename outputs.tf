###############################################################################
# terraform-aws-aisia — outputs (contrat normalisé substrat Swarm).
###############################################################################

output "region" {
  description = "Région AWS du déploiement."
  value       = var.region
}

output "node_count" {
  description = "Nombre de workers provisionnés (hors manager)."
  value       = var.node_count
}

output "manager_ip" {
  description = "IP publique du manager Swarm."
  value       = aws_instance.manager.public_ip
}

output "manager_private_ip" {
  description = "IP privée du manager (advertise-addr Swarm + cible des join)."
  value       = aws_instance.manager.private_ip
}

output "worker_ips" {
  description = "IPs publiques des workers Swarm."
  value       = [for w in aws_instance.worker : w.public_ip]
}

output "vpc_id" {
  description = "ID du VPC AISIA Swarm."
  value       = aws_vpc.this.id
}

output "subnet_id" {
  description = "ID du subnet public hébergeant les nœuds."
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID du Security Group Swarm."
  value       = aws_security_group.swarm.id
}

output "swarm_join_token_path" {
  description = <<-EOT
    Chemin du token worker sur le manager (récupérer après apply) :
      ssh ubuntu@<manager_ip> 'sudo cat /tmp/worker-token'
  EOT
  value       = "/tmp/worker-token"
}

output "swarm_join_command" {
  description = "Gabarit de commande join (le token réel est sur le manager)."
  value       = "docker swarm join --token <WORKER_TOKEN> ${aws_instance.manager.private_ip}:2377"
}

output "endpoints" {
  description = "Endpoints applicatifs exposés par le manager (Traefik HTTP/HTTPS)."
  value = {
    http  = "http://${aws_instance.manager.public_ip}/"
    https = "https://${aws_instance.manager.public_ip}/"
    api   = "https://${aws_instance.manager.public_ip}/v1/"
  }
}

output "next_steps" {
  description = "Étapes post-apply : join workers + déploiement stack AISIA."
  value       = <<-EOT
    1. Récupérer le token worker :
       ssh ubuntu@${aws_instance.manager.public_ip} 'sudo cat /tmp/worker-token'

    2. Joindre chaque worker :
       ssh ubuntu@<worker_ip> \
         "docker swarm join --token <TOKEN> ${aws_instance.manager.private_ip}:2377"

    3. Déployer la stack AISIA (image_tag=${var.image_tag}) :
       docker stack deploy -c stack-aisia.yml aisia
  EOT
}
