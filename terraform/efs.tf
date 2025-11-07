# EFS for OpenRemote Map Data (mapdata.mbtiles)
# This allows sharing large map files across deployments without large EBS volumes

resource "aws_efs_file_system" "openremote_maps" {
  count            = var.enable_efs ? 1 : 0
  creation_token   = "${var.project_name}-${var.environment}-maps"
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = {
    Name = "${var.project_name}-${var.environment}-maps-efs"
  }

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
}

# Security Group for EFS
resource "aws_security_group" "efs" {
  count       = var.enable_efs ? 1 : 0
  name        = "${var.project_name}-${var.environment}-efs-sg"
  description = "Security group for EFS mount targets (NFS access)"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-efs-sg"
  }
}

# Allow NFS access from EC2 instance
resource "aws_security_group_rule" "efs_ingress_ec2" {
  count                    = var.enable_efs ? 1 : 0
  description              = "Allow NFS access from EC2 instances"
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs[0].id
  source_security_group_id = aws_security_group.openremote_ec2.id
}

resource "aws_security_group_rule" "efs_egress" {
  count             = var.enable_efs ? 1 : 0
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.efs[0].id
}

# EFS Mount Targets in each AZ
resource "aws_efs_mount_target" "openremote_maps" {
  count           = var.enable_efs ? length(var.availability_zones) : 0
  file_system_id  = aws_efs_file_system.openremote_maps[0].id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs[0].id]
}

# EFS Access Point for OpenRemote
resource "aws_efs_access_point" "openremote_maps" {
  count          = var.enable_efs ? 1 : 0
  file_system_id = aws_efs_file_system.openremote_maps[0].id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/mapdata"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-maps-access-point"
  }
}

