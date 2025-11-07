# OpenRemote AWS Features & Prerequisites

This document explains the AWS services used by OpenRemote and how they're implemented in this Terraform configuration, based on the [official OpenRemote AWS CloudFormation documentation](https://docs.openremote.io/docs/user-guide/deploying/aws-cloudformation).

## ✅ Core Services (Already Included)

### 1. VPC (Virtual Private Cloud)
**Status:** ✅ **Fully Configured**

- VPC with 10.0.0.0/16 CIDR
- Public and private subnets across 2 AZs
- Internet Gateway and NAT Gateway
- Proper route tables

**Files:** `main.tf`

---

### 2. EC2 (Elastic Compute Cloud)
**Status:** ✅ **Deployed**

- t3.medium instance (2 vCPU, 4GB RAM)
- Ubuntu 22.04 LTS
- Docker & Docker Compose pre-installed
- OpenRemote running in containers
- Elastic IP for stable access

**Files:** `ec2.tf`, `user-data.sh`

---

### 3. Security Groups
**Status:** ✅ **Configured**

| OpenRemote Requirement | Our Implementation | Status |
|------------------------|-------------------|--------|
| `http-access` (80, 443) | `ec2_http`, `ec2_https` rules | ✅ |
| `mqtt-access` (8883) | `ec2_mqtts` rule | ✅ |
| MQTT (1883) | `ec2_mqtt` rule | ✅ Extra! |
| `ssh-access` (22) | `ec2_ssh` rule | ✅ |
| `ping-access` (ICMP) | `ec2_ping` rule (optional) | ✅ |
| `snmp-access` (UDP 162) | `ec2_snmp` rule (optional) | ✅ |

**Files:** `ec2.tf`

**Configuration:**
```hcl
# In terraform.tfvars
enable_icmp_ping = true   # Enable ping for monitoring
enable_snmp      = false  # Enable if you use SNMP monitoring
```

---

## 🆕 Optional Services (Now Available)

### 4. S3 (Simple Storage Service) - For Backups
**Status:** ✅ **NEW - Added**

**What it does:**
- Stores automated PostgreSQL database backups
- Stores Docker volume backups
- Stores configuration backups
- Automatic lifecycle management (30-day retention by default)

**Features:**
- ✅ Encryption at rest (AES256)
- ✅ Versioning enabled
- ✅ Public access blocked
- ✅ Automatic cleanup of old backups
- ✅ Daily automated backups (2 AM)

**Configuration:**
```hcl
# In terraform.tfvars
enable_s3_backups = true       # Enable S3 backups
backup_retention_days = 30     # Keep backups for 30 days
```

**Files:** `s3-backups.tf`, `user-data.sh` (creates backup script)

**Usage:**
```bash
# SSH into instance
ssh ubuntu@<your-ip>

# Manual backup
/opt/openremote/backup.sh

# View backup logs
tail -f /var/log/openremote-backup.log

# List backups in S3
aws s3 ls s3://openremote-dev-backups-<account-id>/backups/
```

**Cost:** ~$0.50-2/month depending on data size

---

### 5. EFS (Elastic File System) - For Map Data
**Status:** ✅ **NEW - Added**

**What it does:**
- Stores large map files (`mapdata.mbtiles`) separately from EC2
- Allows sharing map data across multiple instances
- Automatic scaling - pay only for what you use
- Multi-AZ redundancy

**Features:**
- ✅ Encrypted at rest
- ✅ Lifecycle management (moves to IA after 30 days)
- ✅ NFS mount to `/opt/openremote/mapdata`
- ✅ Security group for NFS access

**Configuration:**
```hcl
# In terraform.tfvars
enable_efs = true  # Enable EFS for map data
```

**Files:** `efs.tf`, `user-data.sh` (auto-mounts EFS)

**Usage:**
```bash
# SSH into instance
ssh ubuntu@<your-ip>

# Map data location
cd /opt/openremote/mapdata

# Upload map files
# Copy your mapdata.mbtiles files here
```

**Cost:** ~$0.30/GB-month (first TB), cheaper for infrequently accessed

---

### 6. Route 53 (DNS Management) - For Custom Domain
**Status:** ✅ **NEW - Template Added**

**What it does:**
- Manages DNS records for your custom domain
- Points your domain to the EC2 instance
- Automatic DNS updates

**Configuration:**

Edit `terraform/route53.tf` and uncomment the resources, then:

```hcl
# In terraform.tfvars
domain_name = "openremote.example.com"

# Option A: Create new hosted zone
create_route53_zone = true

# Option B: Use existing hosted zone
create_route53_zone = false
route53_zone_id = "Z123456789ABC"  # Your existing zone ID
```

**Files:** `route53.tf` (currently commented out)

**Cost:** $0.50/month per hosted zone + $0.40 per million queries

---

## 📊 Complete Feature Matrix

| AWS Service | Included | Enabled by Default | Cost Impact | Configuration |
|-------------|----------|-------------------|-------------|---------------|
| VPC | ✅ | Yes | Free | N/A |
| EC2 | ✅ | Yes | ~$30/month | `ec2_instance_type` |
| Security Groups | ✅ | Yes | Free | Various flags |
| NAT Gateway | ✅ | Yes | ~$33/month | `single_nat_gateway` |
| IAM Roles | ✅ | Yes | Free | N/A |
| **S3 Backups** | ✅ NEW | Yes | ~$1-2/month | `enable_s3_backups` |
| **EFS Maps** | ✅ NEW | No | ~$0.30/GB | `enable_efs` |
| **Route 53** | ✅ NEW | No | ~$0.50/month | `domain_name` |
| ICMP Ping | ✅ NEW | Yes | Free | `enable_icmp_ping` |
| SNMP | ✅ NEW | No | Free | `enable_snmp` |
| CloudFormation | N/A | N/A | Free | Using Terraform instead |
| SNS | ❌ | N/A | N/A | Not needed (CF only) |

## 🚀 Recommended Configuration

### For Production:

```hcl
# terraform.tfvars

# Instance
ec2_instance_type = "t3.medium"  # or t3.large for heavier workloads

# Backups - HIGHLY RECOMMENDED
enable_s3_backups = true
backup_retention_days = 90  # 3 months

# Map Data - If you have large map files
enable_efs = true

# Domain - If you have one
domain_name = "openremote.yourcompany.com"
create_route53_zone = true

# Monitoring
enable_icmp_ping = true
enable_snmp = false  # Only if you use SNMP monitoring

# Security
ssh_allowed_cidr_blocks = ["YOUR_OFFICE_IP/32"]  # Restrict SSH!
```

### For Development/Testing:

```hcl
# terraform.tfvars

# Instance
ec2_instance_type = "t3.small"  # Cheaper for testing

# Backups - Optional for dev
enable_s3_backups = false  # Save $1-2/month

# Map Data - Probably not needed
enable_efs = false

# Domain - Use IP address
domain_name = ""

# Monitoring
enable_icmp_ping = true
```

## 🔄 Applying New Features

If you want to enable S3 backups or EFS on your existing deployment:

### 1. Update Configuration

Edit `terraform/terraform.tfvars`:

```hcl
# Enable S3 backups
enable_s3_backups = true

# Optionally enable EFS
enable_efs = true
```

### 2. Apply Changes

```powershell
cd terraform
terraform plan   # Review changes
terraform apply  # Apply changes
```

### 3. Verify

```powershell
# Check S3 bucket
terraform output s3_backup_bucket_name

# Check EFS (if enabled)
terraform output efs_dns_name
```

## 📝 Differences from OpenRemote CloudFormation

| Feature | CloudFormation Approach | Our Terraform Approach |
|---------|------------------------|----------------------|
| **Infrastructure Tool** | CloudFormation | Terraform (more flexible) |
| **Security Groups** | Named groups (http-access, etc.) | Resource-specific groups |
| **EC2 Key** | Required "openremote" key | Optional (SSM alternative) |
| **Route 53** | Required | Optional (can use IP) |
| **EFS** | Pre-created | Auto-created on demand |
| **S3** | Manual setup | Automated with lifecycle |
| **SNS** | For CloudFormation notifications | Not needed |

## 💰 Updated Cost Estimate with All Features

### Base Configuration (Current):
- EC2 t3.medium: $30/month
- EBS 50GB: $4/month
- NAT Gateway: $33/month
- VPC Flow Logs: $10/month
- **Subtotal: ~$77/month**

### With Optional Features:
- **S3 Backups**: +$1-2/month
- **EFS (10GB maps)**: +$3/month
- **Route 53**: +$0.50/month
- **Total with all features: ~$81-83/month**

## 🔐 Security Notes

### SSH Access
OpenRemote CloudFormation expects a key pair named "openremote". You have two options:

**Option 1: Create "openremote" key pair**
```bash
aws ec2 create-key-pair --key-name openremote --query 'KeyMaterial' --output text > openremote.pem
chmod 400 openremote.pem
```

Then update terraform.tfvars:
```hcl
ec2_key_name = "openremote"
```

**Option 2: Use AWS Systems Manager (No SSH key needed)**
```bash
aws ssm start-session --target $(terraform output -raw ec2_instance_id)
```

Our default approach uses SSM for better security.

## 📚 Additional Resources

- [OpenRemote AWS CloudFormation Guide](https://docs.openremote.io/docs/user-guide/deploying/aws-cloudformation)
- [AWS EFS Documentation](https://docs.aws.amazon.com/efs/)
- [AWS S3 Backup Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/backup-for-s3.html)
- [AWS Route 53 Documentation](https://docs.aws.amazon.com/route53/)

## ✅ Summary

Your Terraform deployment now includes **ALL recommended AWS services** from the OpenRemote documentation:

- ✅ VPC with proper networking
- ✅ EC2 instance with Docker
- ✅ All required security groups
- ✅ **S3 for automated backups** (enabled by default)
- ✅ **EFS for map data** (optional, disabled by default)
- ✅ **Route 53 DNS** (optional, template provided)
- ✅ ICMP ping access (for monitoring)
- ✅ SNMP access (optional)
- ✅ IAM roles for proper permissions

**You're production-ready!** 🚀

