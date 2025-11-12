variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name to be used for resource naming"
  type        = string
  default     = "openremote"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}


variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the EKS cluster API"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets (cost savings, but less HA)"
  type        = bool
  default     = true  # Changed to true for simpler EC2 deployment
}

variable "ec2_instance_type" {
  description = "EC2 instance type for OpenRemote"
  type        = string
  default     = "t3.small"  # 2 vCPU, 2GB RAM - ~$15/month (use t3.medium or t3.large for production)
}

variable "ec2_key_name" {
  description = "SSH key pair name for EC2 instance access (must exist in AWS)"
  type        = string
  default     = ""
}

variable "ec2_ssh_public_key" {
  description = "Public SSH key material that Terraform should register as an EC2 key pair when no key name is supplied"
  type        = string
  default     = ""
}

variable "ssh_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into the EC2 instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this to your IP in production!
}

variable "ec2_volume_size" {
  description = "Root volume size in GB for EC2 instance"
  type        = number
  default     = 50
}

variable "openremote_hostname" {
  description = "Hostname for OpenRemote (will be used in docker-compose)"
  type        = string
  default     = "localhost"
}

variable "enable_s3_backups" {
  description = "Enable S3 bucket for OpenRemote backups"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups in S3"
  type        = number
  default     = 30
}

variable "enable_efs" {
  description = "Enable EFS for map data storage (mapdata.mbtiles)"
  type        = bool
  default     = false  # Set to true if you need to store large map files
}

variable "domain_name" {
  description = "Domain name for OpenRemote (leave empty to use IP address)"
  type        = string
  default     = ""
}

variable "create_route53_zone" {
  description = "Create a new Route 53 hosted zone (false if using existing zone)"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Existing Route 53 hosted zone ID (required if create_route53_zone is false and domain_name is set)"
  type        = string
  default     = ""
}

variable "enable_icmp_ping" {
  description = "Allow ICMP ping for monitoring and diagnostics"
  type        = bool
  default     = true
}

variable "enable_snmp" {
  description = "Allow SNMP access for network monitoring (UDP 162)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "service_hostname" {
  description = "Publieke hostnaam (FQDN) van de OpenRemote instantie"
  type        = string
  default     = ""
  }

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for monitoring and security"
  type        = bool
  default     = true
}
