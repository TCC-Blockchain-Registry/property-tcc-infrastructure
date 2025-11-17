variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "property-tcc"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "demo"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# Database variables
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "core_orchestrator_db"
}

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "db_password" {
  description = "PostgreSQL master password"
  type        = string
  sensitive   = true
  default     = ""  # Will be generated or set via tfvars
}

# ECS Task configuration
variable "frontend_cpu" {
  description = "CPU units for frontend task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "frontend_memory" {
  description = "Memory for frontend task in MB"
  type        = number
  default     = 512
}

variable "bff_cpu" {
  description = "CPU units for BFF task"
  type        = number
  default     = 256
}

variable "bff_memory" {
  description = "Memory for BFF task in MB"
  type        = number
  default     = 512
}

variable "orchestrator_cpu" {
  description = "CPU units for orchestrator task"
  type        = number
  default     = 512
}

variable "orchestrator_memory" {
  description = "Memory for orchestrator task in MB"
  type        = number
  default     = 1024
}

variable "offchain_cpu" {
  description = "CPU units for offchain API task"
  type        = number
  default     = 512
}

variable "offchain_memory" {
  description = "Memory for offchain API task in MB"
  type        = number
  default     = 1024
}

variable "worker_cpu" {
  description = "CPU units for queue worker task"
  type        = number
  default     = 256
}

variable "worker_memory" {
  description = "Memory for queue worker task in MB"
  type        = number
  default     = 512
}

variable "rabbitmq_cpu" {
  description = "CPU units for RabbitMQ task"
  type        = number
  default     = 256
}

variable "rabbitmq_memory" {
  description = "Memory for RabbitMQ task in MB"
  type        = number
  default     = 512
}

variable "besu_cpu" {
  description = "CPU units for each Besu validator task"
  type        = number
  default     = 1024  # 1 vCPU per validator
}

variable "besu_memory" {
  description = "Memory for each Besu validator task in MB"
  type        = number
  default     = 2048  # 2 GB per validator
}

# Service desired counts
variable "frontend_desired_count" {
  description = "Desired number of frontend tasks"
  type        = number
  default     = 2
}

variable "bff_desired_count" {
  description = "Desired number of BFF tasks"
  type        = number
  default     = 2
}

variable "orchestrator_desired_count" {
  description = "Desired number of orchestrator tasks"
  type        = number
  default     = 2
}

variable "offchain_desired_count" {
  description = "Desired number of offchain API tasks"
  type        = number
  default     = 2
}

variable "worker_desired_count" {
  description = "Desired number of queue worker tasks"
  type        = number
  default     = 1
}

variable "rabbitmq_desired_count" {
  description = "Desired number of RabbitMQ tasks"
  type        = number
  default     = 1
}

# Besu validators (4 validators: 2 in each AZ)
variable "besu_validator_count" {
  description = "Total number of Besu validators"
  type        = number
  default     = 4
}

# EFS configuration
variable "efs_performance_mode" {
  description = "EFS performance mode"
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "EFS throughput mode"
  type        = string
  default     = "bursting"
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
