resource "aws_efs_file_system" "besu_data" {
  creation_token   = "${var.project_name}-besu-data"
  performance_mode = var.efs_performance_mode
  throughput_mode  = var.efs_throughput_mode

  encrypted = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "${var.project_name}-besu-data"
  }
}

resource "aws_efs_mount_target" "besu_data" {
  count           = length(var.availability_zones)
  file_system_id  = aws_efs_file_system.besu_data.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_access_point" "besu_validator" {
  count = var.besu_validator_count

  file_system_id = aws_efs_file_system.besu_data.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/validator-${count.index + 1}"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name = "${var.project_name}-besu-validator-${count.index + 1}-ap"
  }
}
