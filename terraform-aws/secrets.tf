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

resource "random_id" "besu_admin_key" {
  byte_length = 32
}

resource "aws_secretsmanager_secret" "besu_admin_key" {
  name = "${var.project_name}/besu/admin-private-key"

  tags = {
    Name = "${var.project_name}-besu-admin-key"
  }
}

resource "aws_secretsmanager_secret_version" "besu_admin_key" {
  secret_id     = aws_secretsmanager_secret.besu_admin_key.id
  secret_string = "0x${random_id.besu_admin_key.hex}"
}

resource "random_id" "besu_orchestrator_key" {
  byte_length = 32
}

resource "aws_secretsmanager_secret" "besu_orchestrator_key" {
  name = "${var.project_name}/besu/orchestrator-private-key"

  tags = {
    Name = "${var.project_name}-besu-orchestrator-key"
  }
}

resource "aws_secretsmanager_secret_version" "besu_orchestrator_key" {
  secret_id     = aws_secretsmanager_secret.besu_orchestrator_key.id
  secret_string = "0x${random_id.besu_orchestrator_key.hex}"
}

resource "random_id" "besu_registrar_key" {
  byte_length = 32
}

resource "aws_secretsmanager_secret" "besu_registrar_key" {
  name = "${var.project_name}/besu/registrar-private-key"

  tags = {
    Name = "${var.project_name}-besu-registrar-key"
  }
}

resource "aws_secretsmanager_secret_version" "besu_registrar_key" {
  secret_id     = aws_secretsmanager_secret.besu_registrar_key.id
  secret_string = "0x${random_id.besu_registrar_key.hex}"
}
