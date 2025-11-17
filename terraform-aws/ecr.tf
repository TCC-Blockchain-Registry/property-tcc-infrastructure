# ECR Repositories for all services

locals {
  ecr_repos = [
    "frontend",
    "bff-gateway",
    "orchestrator",
    "offchain-api",
    "queue-worker",
    "rabbitmq",
    "besu-validator"
  ]
}

resource "aws_ecr_repository" "repos" {
  for_each = toset(local.ecr_repos)

  name                 = "${var.project_name}-${each.value}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name    = "${var.project_name}-${each.value}"
    Service = each.value
  }
}

# Lifecycle policy to keep only last 5 images (cost optimization)
resource "aws_ecr_lifecycle_policy" "repo_policy" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# Output ECR repository URLs
output "ecr_repository_urls" {
  description = "URLs for ECR repositories"
  value = {
    for repo in aws_ecr_repository.repos :
    repo.name => repo.repository_url
  }
}
