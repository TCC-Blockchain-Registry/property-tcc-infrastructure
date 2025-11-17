# Security Group for Application Load Balancer
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Security Group for ECS Tasks (Frontend, BFF, Orchestrator, Offchain, Worker)
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  # Frontend
  ingress {
    description     = "Frontend from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # BFF Gateway
  ingress {
    description     = "BFF from ALB"
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Orchestrator
  ingress {
    description     = "Orchestrator from ALB and BFF"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Orchestrator (manual port for local dev compatibility)
  ingress {
    description = "Orchestrator manual port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    self        = true
  }

  # Offchain API
  ingress {
    description     = "Offchain API from tasks"
    from_port       = 3001
    to_port         = 3001
    protocol        = "tcp"
    self            = true
  }

  # RabbitMQ AMQP
  ingress {
    description = "RabbitMQ AMQP"
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    self        = true
  }

  # RabbitMQ Management UI
  ingress {
    description = "RabbitMQ Management"
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    self        = true
  }

  # Allow tasks to communicate with each other
  ingress {
    description = "Inter-task communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ecs-tasks-sg"
  }
}

# Security Group for Besu Validators
resource "aws_security_group" "besu" {
  name        = "${var.project_name}-besu-sg"
  description = "Security group for Besu blockchain validators"
  vpc_id      = aws_vpc.main.id

  # Besu RPC (JSON-RPC) - accessible by Offchain API
  ingress {
    description     = "Besu RPC from ECS tasks"
    from_port       = 8545
    to_port         = 8548
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  # Besu RPC - allow validators to query each other
  ingress {
    description = "Besu RPC inter-validator"
    from_port   = 8545
    to_port     = 8548
    protocol    = "tcp"
    self        = true
  }

  # Besu P2P TCP (validator communication)
  ingress {
    description = "Besu P2P TCP"
    from_port   = 30303
    to_port     = 30306
    protocol    = "tcp"
    self        = true
  }

  # Besu P2P UDP (discovery)
  ingress {
    description = "Besu P2P UDP"
    from_port   = 30303
    to_port     = 30306
    protocol    = "udp"
    self        = true
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-besu-sg"
  }
}

# Security Group for RDS PostgreSQL
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# Security Group for EFS
resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs-sg"
  description = "Security group for EFS (Besu data storage)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS from Besu tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.besu.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-efs-sg"
  }
}
