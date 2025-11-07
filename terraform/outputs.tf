output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}


output "availability_zones" {
  description = "Availability zones used"
  value       = var.availability_zones
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

# EC2 Instance Outputs
output "ec2_instance_id" {
  description = "ID of the OpenRemote EC2 instance"
  value       = aws_instance.openremote.id
}

output "ec2_instance_public_ip" {
  description = "Public IP address of the OpenRemote EC2 instance"
  value       = aws_eip.openremote.public_ip
}

output "ec2_instance_private_ip" {
  description = "Private IP address of the OpenRemote EC2 instance"
  value       = aws_instance.openremote.private_ip
}

output "ec2_security_group_id" {
  description = "Security group ID for the OpenRemote EC2 instance"
  value       = aws_security_group.openremote_ec2.id
}

output "openremote_url" {
  description = "URL to access OpenRemote"
  value       = "http://${aws_eip.openremote.public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = var.ec2_key_name != "" ? "ssh -i ~/.ssh/${var.ec2_key_name}.pem ubuntu@${aws_eip.openremote.public_ip}" : "No SSH key configured. Use AWS Systems Manager Session Manager instead."
}

# S3 Backup Bucket Outputs
output "s3_backup_bucket_name" {
  description = "S3 bucket name for backups"
  value       = var.enable_s3_backups ? aws_s3_bucket.openremote_backups[0].id : "S3 backups not enabled"
}

output "s3_backup_bucket_arn" {
  description = "S3 bucket ARN for backups"
  value       = var.enable_s3_backups ? aws_s3_bucket.openremote_backups[0].arn : "S3 backups not enabled"
}

# EFS Outputs
output "efs_id" {
  description = "EFS file system ID for map data"
  value       = var.enable_efs ? aws_efs_file_system.openremote_maps[0].id : "EFS not enabled"
}

output "efs_dns_name" {
  description = "EFS DNS name for mounting"
  value       = var.enable_efs ? aws_efs_file_system.openremote_maps[0].dns_name : "EFS not enabled"
}

# Route 53 Outputs
output "domain_name" {
  description = "Configured domain name"
  value       = var.domain_name != "" ? var.domain_name : "No domain configured - using IP address"
}

