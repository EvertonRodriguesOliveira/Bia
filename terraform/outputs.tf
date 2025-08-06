# Outputs for BIA Terraform configuration

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.bia.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.bia.zone_id
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.bia.repository_url
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.bia.endpoint
  sensitive   = true
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.bia.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.bia.name
}

output "security_group_alb_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.bia_alb.id
}

output "security_group_ec2_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.bia_ec2.id
}

output "security_group_db_id" {
  description = "ID of the database security group"
  value       = aws_security_group.bia_db.id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.bia.arn
}
