# Secrets Manager for application secrets

# JWT Secret
resource "random_password" "jwt_secret" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name = "${var.project_name}/jwt-secret"

  tags = {
    Name = "${var.project_name}-jwt-secret"
  }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}

# RabbitMQ Admin Password
resource "random_password" "rabbitmq_password" {
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret" "rabbitmq_password" {
  name = "${var.project_name}/rabbitmq/password"

  tags = {
    Name = "${var.project_name}-rabbitmq-password"
  }
}

resource "aws_secretsmanager_secret_version" "rabbitmq_password" {
  secret_id     = aws_secretsmanager_secret.rabbitmq_password.id
  secret_string = random_password.rabbitmq_password.result
}

# Besu Private Keys
# These secrets MUST be created manually BEFORE running terraform apply
# Use the script: ./scripts/2-create-secrets.sh

data "aws_secretsmanager_secret" "besu_admin_key" {
  name = "${var.project_name}/besu/admin-private-key"
}

data "aws_secretsmanager_secret_version" "besu_admin_key" {
  secret_id = data.aws_secretsmanager_secret.besu_admin_key.id
}

data "aws_secretsmanager_secret" "besu_orchestrator_key" {
  name = "${var.project_name}/besu/orchestrator-private-key"
}

data "aws_secretsmanager_secret_version" "besu_orchestrator_key" {
  secret_id = data.aws_secretsmanager_secret.besu_orchestrator_key.id
}

data "aws_secretsmanager_secret" "besu_registrar_key" {
  name = "${var.project_name}/besu/registrar-private-key"
}

data "aws_secretsmanager_secret_version" "besu_registrar_key" {
  secret_id = data.aws_secretsmanager_secret.besu_registrar_key.id
}
