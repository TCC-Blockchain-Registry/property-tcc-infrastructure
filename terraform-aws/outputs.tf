
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "URL of the Application Load Balancer"
  value       = "http://${aws_lb.main.dns_name}"
}

output "internal_alb_dns_name" {
  description = "DNS name of the Internal ALB"
  value       = aws_lb.internal.dns_name
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.postgres.db_name
}

output "efs_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.besu_data.id
}

output "efs_dns_name" {
  description = "EFS DNS name for mounting"
  value       = aws_efs_file_system.besu_data.dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "service_discovery_namespace" {
  description = "Service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "jwt_secret_arn" {
  description = "ARN of JWT secret in Secrets Manager"
  value       = aws_secretsmanager_secret.jwt_secret.arn
  sensitive   = true
}

output "db_password_secret_arn" {
  description = "ARN of database password secret"
  value       = aws_secretsmanager_secret.db_password.arn
  sensitive   = true
}

output "rabbitmq_password_secret_arn" {
  description = "ARN of RabbitMQ password secret"
  value       = aws_secretsmanager_secret.rabbitmq_password.arn
  sensitive   = true
}

output "access_commands" {
  description = "Useful commands for accessing the system"
  value = {
    frontend_url       = "http://${aws_lb.main.dns_name}"
    bff_api_url       = "http://${aws_lb.main.dns_name}/api"
    orchestrator_url  = "http://${aws_lb.main.dns_name}/actuator/health"
    ecs_cluster       = "aws ecs list-services --cluster ${aws_ecs_cluster.main.name}"
    logs_frontend     = "aws logs tail /ecs/${var.project_name}-frontend --follow"
    logs_bff          = "aws logs tail /ecs/${var.project_name}-bff-gateway --follow"
    logs_orchestrator = "aws logs tail /ecs/${var.project_name}-orchestrator --follow"
  }
}

output "deployment_summary" {
  description = "Deployment summary for TCC presentation"
  value = {
    cluster_name      = aws_ecs_cluster.main.name
    availability_zones = var.availability_zones
    total_services    = 7
    clustered_services = ["bff-gateway (2 tasks)", "orchestrator (2 tasks)"]
    besu_validators   = "4 validators (single AZ)"
    load_balancer     = aws_lb.main.dns_name
    database          = "PostgreSQL ${aws_db_instance.postgres.engine_version} (${var.db_instance_class})"
    storage           = "EFS for Besu blockchain data"
  }
}
