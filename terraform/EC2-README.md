# OpenRemote on AWS EC2 - Complete Deployment Guide

This Terraform configuration deploys OpenRemote on a single EC2 instance with Docker. This is a simple, cost-effective solution perfect for:

- 🧪 Testing and development
- 📊 Small to medium deployments
- 💰 Budget-conscious projects
- 🚀 Quick setup and deployment

## What Gets Deployed

### Infrastructure
- ✅ **VPC** with public and private subnets across 2 AZs
- ✅ **EC2 Instance** (t3.small: 2 vCPU, 2GB RAM - upgradeable to t3.medium or t3.large)
- ✅ **Elastic IP** for stable public access
- ✅ **Security Group** with proper firewall rules
- ✅ **1 NAT Gateway** (for private subnet internet access)
- ✅ **VPC Flow Logs** (optional)

### OpenRemote Stack (via Docker)
- ✅ **PostgreSQL** database
- ✅ **Keycloak** authentication server
- ✅ **OpenRemote Manager** main application
- ✅ **Automatic startup** on instance reboot

## Quick Start

### Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** installed (>= 1.0)
3. **AWS CLI** installed and configured
4. **(Optional)** SSH key pair in AWS for instance access

### Step 1: Configure AWS Credentials

```powershell
# Windows PowerShell
$env:AWS_ACCESS_KEY_ID = "your-access-key"
$env:AWS_SECRET_ACCESS_KEY = "your-secret-key"

# Or use AWS CLI
aws configure
```

### Step 2: Configure Variables

```powershell
cd terraform
Copy-Item terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars  # Edit with your settings
```

**Important settings to configure:**

```hcl
# Your AWS region
aws_region = "eu-west-1"

# Instance configuration
ec2_instance_type = "t3.small"     # 2 vCPU, 2GB RAM (~$15/month)
                                   # For production: t3.medium (4GB) or t3.large (8GB)
ec2_volume_size   = 50             # GB of storage

# SSH key (optional - if you want SSH access)
ec2_key_name = "my-key-pair"       # Must exist in AWS!

# Security - RESTRICT THIS!
ssh_allowed_cidr_blocks = ["1.2.3.4/32"]  # Your IP address

# Domain name (optional - use your domain if you have one)
openremote_hostname = "openremote.example.com"
```

### Step 3: Deploy

#### Windows PowerShell
```powershell
.\deploy.ps1
```

#### Git Bash / Linux / Mac
```bash
./deploy.sh
```

#### Manual Deployment
```bash
terraform init
terraform plan
terraform apply
```

### Step 4: Access OpenRemote

After deployment (takes ~5 minutes), get the access URL:

```bash
terraform output openremote_url
```

Or view all outputs:

```bash
terraform output
```

**Example output:**
```
openremote_url = "http://54.123.45.67"
ec2_instance_public_ip = "54.123.45.67"
ssh_command = "ssh -i ~/.ssh/my-key.pem ubuntu@54.123.45.67"
```

### Step 5: Login to OpenRemote

1. Open the URL in your browser: `http://<your-ip>`
2. Default credentials:
   - **Username:** `admin`
   - **Password:** `secret`

⚠️ **Change the password immediately after first login!**

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Internet                           │
└─────────────────┬───────────────────────────────────────┘
                  │
                  │ HTTP/HTTPS/MQTT
                  ▼
┌─────────────────────────────────────────────────────────┐
│              AWS VPC (10.0.0.0/16)                      │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │        Public Subnet (10.0.1.0/24)                │ │
│  │                                                   │ │
│  │  ┌─────────────────────────────────────────────┐ │ │
│  │  │  EC2 Instance (Ubuntu 22.04 + Docker)      │ │ │
│  │  │                                             │ │ │
│  │  │  ┌──────────────────────────────────────┐  │ │ │
│  │  │  │  OpenRemote Stack                    │  │ │ │
│  │  │  │  • PostgreSQL (Database)             │  │ │ │
│  │  │  │  • Keycloak (Authentication)         │  │ │ │
│  │  │  │  • Manager (Main Application)        │  │ │ │
│  │  │  └──────────────────────────────────────┘  │ │ │
│  │  │                                             │ │ │
│  │  │  Ports:                                     │ │ │
│  │  │  • 80/443 (HTTP/HTTPS)                     │ │ │
│  │  │  • 1883/8883 (MQTT/MQTTS)                  │ │ │
│  │  │  • 22 (SSH)                                 │ │ │
│  │  └─────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Cost Breakdown

### Monthly Costs (eu-west-1)

| Resource | Details | Monthly Cost |
|----------|---------|--------------|
| EC2 Instance | t3.small (on-demand) | ~$15 |
| EBS Volume | 50 GB gp3 | ~$4 |
| Elastic IP | Associated to instance | Free |
| Data Transfer | First 100 GB free | $0-10 |
| NAT Gateway | Single gateway | ~$33 |
| VPC/Subnets | Free | $0 |
| **TOTAL** | | **~$52-62/month** |

**Instance Size Comparison:**
| Instance Type | vCPU | RAM | Monthly Cost | Best For |
|---------------|------|-----|--------------|----------|
| t3.small | 2 | 2GB | ~$15 | Light testing, dev |
| t3.medium | 2 | 4GB | ~$30 | Small production |
| t3.large | 2 | 8GB | ~$60 | Production |

### Cost Optimization Options

1. **Use Spot Instance** (save ~70%)
   ```hcl
   # Add to ec2.tf
   instance_market_options {
     market_type = "spot"
   }
   ```

2. **Reserved Instance** (save ~40% for 1-year commitment)
   - Purchase through AWS Console

3. **Upgrade instance** for production workloads
   ```hcl
   # In terraform.tfvars
   ec2_instance_type = "t3.medium"  # 2 vCPU, 4GB RAM - ~$30/month
   # or
   ec2_instance_type = "t3.large"   # 2 vCPU, 8GB RAM - ~$60/month
   ```

4. **Stop instance when not in use**
   ```bash
   aws ec2 stop-instances --instance-ids $(terraform output -raw ec2_instance_id)
   ```

## Security Best Practices

### 1. Restrict SSH Access

⚠️ **CRITICAL**: Don't leave SSH open to the world!

```hcl
# terraform.tfvars
ssh_allowed_cidr_blocks = ["YOUR_IP/32"]  # Only your IP
```

### 2. Use SSH Key Authentication

Create an SSH key pair in AWS:

```bash
aws ec2 create-key-pair --key-name openremote-key --query 'KeyMaterial' --output text > openremote-key.pem
chmod 400 openremote-key.pem
```

Then update `terraform.tfvars`:
```hcl
ec2_key_name = "openremote-key"
```

### 3. Use HTTPS with a Real Certificate

After deployment, configure a domain name and use Let's Encrypt:

```bash
# SSH into instance
ssh -i openremote-key.pem ubuntu@<your-ip>

# Install certbot
sudo apt-get install certbot

# Get certificate
sudo certbot certonly --standalone -d your-domain.com
```

### 4. Change Default Passwords

Edit `/opt/openremote/docker-compose.yml` and change:
- Keycloak admin password
- PostgreSQL password
- OpenRemote admin password

### 5. Enable AWS Systems Manager

Instead of SSH, use AWS Systems Manager Session Manager (already enabled):

```bash
aws ssm start-session --target $(terraform output -raw ec2_instance_id)
```

## Managing OpenRemote

### SSH into the Instance

```bash
# Get SSH command
terraform output ssh_command

# Or manually
ssh -i ~/.ssh/your-key.pem ubuntu@<your-ip>
```

### View Logs

```bash
cd /opt/openremote
docker-compose logs -f
```

### Restart Services

```bash
# Restart all services
cd /opt/openremote
docker-compose restart

# Or use systemd
sudo systemctl restart openremote
```

### Update OpenRemote

```bash
cd /opt/openremote
docker-compose pull
docker-compose up -d
```

### Backup Data

```bash
# Backup PostgreSQL data
docker-compose exec postgresql pg_dump -U postgres openremote > backup.sql

# Backup volumes
docker run --rm -v openremote_postgresql-data:/data -v $(pwd):/backup ubuntu tar czf /backup/postgresql-data.tar.gz /data
```

## Troubleshooting

### OpenRemote Not Accessible

1. **Check security group rules:**
   ```bash
   aws ec2 describe-security-groups --group-ids $(terraform output -raw ec2_security_group_id)
   ```

2. **Check instance status:**
   ```bash
   aws ec2 describe-instance-status --instance-ids $(terraform output -raw ec2_instance_id)
   ```

3. **Check Docker containers:**
   ```bash
   ssh ubuntu@<your-ip>
   cd /opt/openremote
   docker-compose ps
   docker-compose logs
   ```

### Docker Services Not Running

```bash
# SSH into instance
ssh ubuntu@<your-ip>

# Check Docker status
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Restart OpenRemote
cd /opt/openremote
docker-compose up -d
```

### Out of Disk Space

```bash
# Check disk usage
df -h

# Clean up Docker
docker system prune -a --volumes

# Or increase volume size in terraform.tfvars:
ec2_volume_size = 100  # Increase to 100 GB
```

Then run `terraform apply` to resize the volume.

### Performance Issues

Consider upgrading the instance type:

```hcl
# terraform.tfvars
ec2_instance_type = "t3.xlarge"  # 4 vCPU, 16GB RAM
```

Then run `terraform apply`.

## Scaling Options

### Vertical Scaling (More Resources)

Upgrade instance type in `terraform.tfvars`:

```hcl
# For small to medium deployments
ec2_instance_type = "t3.medium"   # 2 vCPU, 4GB RAM (~$30/month)
ec2_instance_type = "t3.large"    # 2 vCPU, 8GB RAM (~$60/month)

# For larger deployments
ec2_instance_type = "t3.xlarge"   # 4 vCPU, 16GB RAM (~$120/month)
ec2_instance_type = "t3.2xlarge"  # 8 vCPU, 32GB RAM (~$240/month)
```

Then run `terraform apply` to resize.

### Horizontal Scaling (Multiple Instances)

For production, consider:
- Moving to EKS (Kubernetes) for true horizontal scaling
- Using RDS for PostgreSQL (managed database)
- Adding a load balancer for multiple instances
- Separating PostgreSQL to its own instance

## Cleanup

### Destroy Infrastructure

```powershell
# Windows PowerShell
.\destroy.ps1

# Git Bash / Linux / Mac
./destroy.sh

# Or manually
terraform destroy
```

⚠️ **WARNING**: This permanently deletes everything, including data!

## Upgrading to Production

When ready for production, consider:

1. **Managed Database**: Use AWS RDS instead of Docker PostgreSQL
2. **Load Balancer**: Add an Application Load Balancer
3. **Auto Scaling**: Create an Auto Scaling Group
4. **HTTPS**: Use AWS Certificate Manager for SSL certificates
5. **Monitoring**: Enable CloudWatch detailed monitoring
6. **Backups**: Enable automated EBS snapshots
7. **Multi-AZ**: Deploy across multiple availability zones

## Support

- OpenRemote Documentation: https://github.com/openremote/openremote
- AWS EC2 Documentation: https://docs.aws.amazon.com/ec2/
- Docker Documentation: https://docs.docker.com/

## Next Steps

1. ✅ Deploy infrastructure with `./deploy.ps1`
2. 🌐 Access OpenRemote at the provided URL
3. 🔐 Change default passwords
4. 🏠 Configure your domain name (optional)
5. 🔒 Set up HTTPS with Let's Encrypt (optional)
6. 📱 Start connecting devices and creating automations!

