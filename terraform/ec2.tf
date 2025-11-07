# EC2 Instance for OpenRemote

# Get latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for EC2 Instance
resource "aws_security_group" "openremote_ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Security group for OpenRemote EC2 instance"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-sg"
  }
}

# SSH access
resource "aws_security_group_rule" "ec2_ssh" {
  description       = "Allow SSH access"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_allowed_cidr_blocks
  security_group_id = aws_security_group.openremote_ec2.id
}

# HTTP access
resource "aws_security_group_rule" "ec2_http" {
  description       = "Allow HTTP access"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.openremote_ec2.id
}

# HTTPS access
resource "aws_security_group_rule" "ec2_https" {
  description       = "Allow HTTPS access"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.openremote_ec2.id
}

# MQTT access
resource "aws_security_group_rule" "ec2_mqtt" {
  description       = "Allow MQTT access"
  type              = "ingress"
  from_port         = 1883
  to_port           = 1883
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.openremote_ec2.id
}

# MQTTS access
resource "aws_security_group_rule" "ec2_mqtts" {
  description       = "Allow MQTTS access"
  type              = "ingress"
  from_port         = 8883
  to_port           = 8883
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.openremote_ec2.id
}

# ICMP Ping access (for monitoring)
resource "aws_security_group_rule" "ec2_ping" {
  count             = var.enable_icmp_ping ? 1 : 0
  description       = "Allow ICMP ping for monitoring"
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.openremote_ec2.id
}

# SNMP access (for network monitoring)
resource "aws_security_group_rule" "ec2_snmp" {
  count             = var.enable_snmp ? 1 : 0
  description       = "Allow SNMP access"
  type              = "ingress"
  from_port         = 162
  to_port           = 162
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.openremote_ec2.id
}

# Allow all outbound traffic
resource "aws_security_group_rule" "ec2_egress" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.openremote_ec2.id
}

# IAM Role for EC2 Instance (for CloudWatch, SSM, etc.)
resource "aws_iam_role" "openremote_ec2" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-role"
  }
}

# Attach SSM policy for Systems Manager access (optional, but useful)
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.openremote_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch policy for logs
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.openremote_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "openremote_ec2" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.openremote_ec2.name

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-profile"
  }
}

# User Data Script to install Docker and run OpenRemote
locals {
  user_data = templatefile("${path.module}/user-data.sh", {
    hostname        = var.openremote_hostname
    efs_dns_name    = var.enable_efs ? aws_efs_file_system.openremote_maps[0].dns_name : "EFS not enabled"
    s3_bucket_name  = var.enable_s3_backups ? aws_s3_bucket.openremote_backups[0].id : "S3 backups not enabled"
  })
}

# EC2 Instance
resource "aws_instance" "openremote" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.openremote_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.openremote_ec2.name
  key_name               = var.ec2_key_name != "" ? var.ec2_key_name : null

  root_block_device {
    volume_size           = var.ec2_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-${var.environment}-root-volume"
    }
  }

  user_data = local.user_data

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-openremote"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# Elastic IP for stable public access
resource "aws_eip" "openremote" {
  instance = aws_instance.openremote.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-openremote-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

