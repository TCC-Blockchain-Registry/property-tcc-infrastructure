resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.frontend_cpu
  memory                   = var.frontend_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "${aws_ecr_repository.repos["frontend"].repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "VITE_BFF_API_URL"
          value = "http://${aws_lb.main.dns_name}/api"
        },
        {
          name  = "VITE_CHAIN_ID"
          value = "1337"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs["frontend"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:80 || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-frontend"
  }
}

resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.frontend_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name = "${var.project_name}-frontend-service"
  }
}

resource "aws_ecs_task_definition" "bff" {
  family                   = "${var.project_name}-bff-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.bff_cpu
  memory                   = var.bff_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "bff-gateway"
      image     = "${aws_ecr_repository.repos["bff-gateway"].repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 4000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = "4000"
        },
        {
          name  = "ORCHESTRATOR_URL"
          value = "http://${var.project_name}-orchestrator.${var.project_name}.local:8081"
        },
        {
          name  = "OFFCHAIN_API_URL"
          value = "http://${aws_lb.internal.dns_name}"
        },
        {
          name  = "NODE_ENV"
          value = "production"
        }
      ]

      secrets = [
        {
          name      = "JWT_SECRET"
          valueFrom = aws_secretsmanager_secret.jwt_secret.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs["bff-gateway"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:4000/api/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-bff-gateway"
  }
}

resource "aws_ecs_service" "bff" {
  name            = "${var.project_name}-bff-gateway"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.bff.arn
  desired_count   = var.bff_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.bff.arn
    container_name   = "bff-gateway"
    container_port   = 4000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.bff.arn
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name = "${var.project_name}-bff-gateway-service"
  }
}

resource "aws_service_discovery_service" "bff" {
  name = "${var.project_name}-bff-gateway"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "orchestrator" {
  family                   = "${var.project_name}-orchestrator"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.orchestrator_cpu
  memory                   = var.orchestrator_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "orchestrator"
      image     = "${aws_ecr_repository.repos["orchestrator"].repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8081
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "SERVER_PORT"
          value = "8081"
        },
        {
          name  = "SPRING_DATASOURCE_URL"
          value = "jdbc:postgresql://${aws_db_instance.postgres.endpoint}/${aws_db_instance.postgres.db_name}"
        },
        {
          name  = "SPRING_DATASOURCE_USERNAME"
          value = "postgres"
        },
        {
          name  = "SPRING_RABBITMQ_HOST"
          value = "${var.project_name}-rabbitmq.${var.project_name}.local"
        },
        {
          name  = "SPRING_RABBITMQ_PORT"
          value = "5672"
        },
        {
          name  = "SPRING_RABBITMQ_USERNAME"
          value = "admin"
        },
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "production"
        },
        {
          name  = "OFFCHAIN_API_URL"
          value = "http://${aws_lb.internal.dns_name}"
        }
      ]

      secrets = [
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = aws_secretsmanager_secret.db_password.arn
        },
        {
          name      = "SPRING_RABBITMQ_PASSWORD"
          valueFrom = aws_secretsmanager_secret.rabbitmq_password.arn
        },
        {
          name      = "JWT_SECRET"
          valueFrom = aws_secretsmanager_secret.jwt_secret.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs["orchestrator"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8081/actuator/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 120
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-orchestrator"
  }
}

resource "aws_ecs_service" "orchestrator" {
  name            = "${var.project_name}-orchestrator"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.orchestrator.arn
  desired_count   = var.orchestrator_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.orchestrator.arn
    container_name   = "orchestrator"
    container_port   = 8081
  }

  service_registries {
    registry_arn = aws_service_discovery_service.orchestrator.arn
  }

  depends_on = [
    aws_lb_listener.http,
    aws_db_instance.postgres
  ]

  tags = {
    Name = "${var.project_name}-orchestrator-service"
  }
}

resource "aws_service_discovery_service" "orchestrator" {
  name = "${var.project_name}-orchestrator"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "offchain" {
  family                   = "${var.project_name}-offchain-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.offchain_cpu
  memory                   = var.offchain_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "offchain-api"
      image     = "${aws_ecr_repository.repos["offchain-api"].repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 3001
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = "3001"
        },
        {
          name  = "RPC_URL"
          value = "http://${var.project_name}-besu-validator-1.${var.project_name}.local:8545"
        },
        {
          name  = "CHAIN_ID"
          value = "1337"
        },
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "PROPERTY_TITLE_ADDRESS"
          value = var.property_title_address
        },
        {
          name  = "APPROVALS_MODULE_ADDRESS"
          value = var.approvals_module_address
        },
        {
          name  = "REGISTRY_MD_ADDRESS"
          value = var.registry_md_address
        }
      ]

      secrets = [
        {
          name      = "ADMIN_PRIVATE_KEY"
          valueFrom = aws_secretsmanager_secret.besu_admin_key.arn
        },
        {
          name      = "ORCHESTRATOR_PRIVATE_KEY"
          valueFrom = aws_secretsmanager_secret.besu_orchestrator_key.arn
        },
        {
          name      = "REGISTRAR_PRIVATE_KEY"
          valueFrom = aws_secretsmanager_secret.besu_registrar_key.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs["offchain-api"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3001/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-offchain-api"
  }
}

resource "aws_ecs_service" "offchain" {
  name            = "${var.project_name}-offchain-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.offchain.arn
  desired_count   = var.offchain_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.offchain_internal.arn
    container_name   = "offchain-api"
    container_port   = 3001
  }

  service_registries {
    registry_arn = aws_service_discovery_service.offchain.arn
  }

  depends_on = [aws_lb_listener.internal]

  tags = {
    Name = "${var.project_name}-offchain-api-service"
  }
}

resource "aws_service_discovery_service" "offchain" {
  name = "${var.project_name}-offchain-api"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "queue_worker" {
  family                   = "${var.project_name}-queue-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.worker_cpu
  memory                   = var.worker_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "queue-worker"
      image     = "${aws_ecr_repository.repos["queue-worker"].repository_url}:latest"
      essential = true

      environment = [
        {
          name  = "RABBITMQ_HOST"
          value = "${var.project_name}-rabbitmq.${var.project_name}.local"
        },
        {
          name  = "RABBITMQ_PORT"
          value = "5672"
        },
        {
          name  = "RABBITMQ_USER"
          value = "admin"
        },
        {
          name  = "OFFCHAIN_API_URL"
          value = "http://${aws_lb.internal.dns_name}"
        },
        {
          name  = "ORCHESTRATOR_URL"
          value = "http://${var.project_name}-orchestrator.${var.project_name}.local:8081"
        },
        {
          name  = "NODE_ENV"
          value = "production"
        }
      ]

      secrets = [
        {
          name      = "RABBITMQ_PASSWORD"
          valueFrom = aws_secretsmanager_secret.rabbitmq_password.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs["queue-worker"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "pgrep -f node || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-queue-worker"
  }
}

resource "aws_ecs_service" "queue_worker" {
  name            = "${var.project_name}-queue-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.queue_worker.arn
  desired_count   = var.worker_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  depends_on = [aws_ecs_service.rabbitmq]

  tags = {
    Name = "${var.project_name}-queue-worker-service"
  }
}

resource "aws_ecs_task_definition" "rabbitmq" {
  family                   = "${var.project_name}-rabbitmq"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.rabbitmq_cpu
  memory                   = var.rabbitmq_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "rabbitmq"
      image     = "${aws_ecr_repository.repos["rabbitmq"].repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 5672
          protocol      = "tcp"
        },
        {
          containerPort = 15672
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "RABBITMQ_DEFAULT_USER"
          value = "admin"
        }
      ]

      secrets = [
        {
          name      = "RABBITMQ_DEFAULT_PASS"
          valueFrom = aws_secretsmanager_secret.rabbitmq_password.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs["rabbitmq"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "rabbitmq-diagnostics -q ping || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-rabbitmq"
  }
}

resource "aws_ecs_service" "rabbitmq" {
  name            = "${var.project_name}-rabbitmq"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.rabbitmq.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.rabbitmq.arn
  }

  tags = {
    Name = "${var.project_name}-rabbitmq-service"
  }
}

resource "aws_service_discovery_service" "rabbitmq" {
  name = "${var.project_name}-rabbitmq"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "besu_validator" {
  for_each                 = toset(["1", "2", "3", "4"])
  family                   = "${var.project_name}-besu-validator-${each.value}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.besu_cpu
  memory                   = var.besu_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  volume {
    name = "besu-data"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.besu_data.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.besu_validator[tonumber(each.value) - 1].id
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "besu-validator-${each.value}"
      image     = "${aws_ecr_repository.repos["besu-validator"].repository_url}:latest"
      essential = true
      portMappings = [
        { containerPort = 8545, protocol = "tcp" },
        { containerPort = 30303, protocol = "tcp" },
        { containerPort = 30303, protocol = "udp" }
      ]
      environment = [
        { name = "BESU_NODE_ID", value = "validator-${each.value}" }
      ]
      mountPoints = [
        { sourceVolume = "besu-data", containerPath = "/opt/besu/data", readOnly = false }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs["besu-validator-${each.value}"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8545 -X POST -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}' || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 180
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-besu-validator-${each.value}"
  }
}

resource "aws_ecs_service" "besu_validator" {
  for_each        = toset(["1", "2", "3", "4"])
  name            = "${var.project_name}-besu-validator-${each.value}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.besu_validator[each.value].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    # Single AZ deployment for cost optimization
    subnets          = [aws_subnet.private[0].id]
    security_groups  = [aws_security_group.besu.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.besu_validator[each.value].arn
  }

  tags = {
    Name = "${var.project_name}-besu-validator-${each.value}-service"
  }
}

resource "aws_service_discovery_service" "besu_validator" {
  for_each = toset(["1", "2", "3", "4"])
  name     = "${var.project_name}-besu-validator-${each.value}"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

