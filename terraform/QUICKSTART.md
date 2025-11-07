# Quick Start Guide - OpenRemote on AWS EC2

This guide will help you deploy OpenRemote on a single EC2 instance with Docker. Simple, fast, and cost-effective!

📖 **For detailed documentation, see [EC2-README.md](EC2-README.md)**

> **Note:** This guide is for EC2-based deployment. All EKS/Kubernetes related files have been removed.

## For Windows Users

You have several options to run the deployment scripts:

### Option 1: Git Bash (Recommended)
1. Install [Git for Windows](https://git-scm.com/download/win) (includes Git Bash)
2. Open Git Bash
3. Navigate to the terraform directory
4. Run: `./deploy.sh`

### Option 2: Windows Subsystem for Linux (WSL)
1. Install [WSL](https://docs.microsoft.com/en-us/windows/wsl/install)
2. Open WSL terminal
3. Navigate to the terraform directory
4. Run: `./deploy.sh`

### Option 3: PowerShell (Manual Steps)
If you prefer PowerShell, follow these manual steps:

```powershell
# Navigate to terraform directory
cd terraform

# Check prerequisites
terraform --version
aws --version
aws sts get-caller-identity

# Copy example config
Copy-Item terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your preferred editor
notepad terraform.tfvars

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -out=tfplan

# Apply deployment
terraform apply tfplan

# View outputs
terraform output

# Save outputs to JSON
terraform output -json | Out-File -FilePath terraform-outputs.json
```

## For Linux/Mac Users

Simply run the deployment script:

```bash
cd terraform
./deploy.sh
```

## Manual Deployment Steps (All Platforms)

### 1. Configure AWS Credentials

```bash
# Set environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_SESSION_TOKEN="your-session-token"  # if using temporary credentials

# OR use AWS CLI
aws configure
```

### 2. Create Configuration File

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:
- Change `aws_region` if needed (default: eu-west-1)
- Change `project_name` and `environment` as desired
- **IMPORTANT**: Update `allowed_cidr_blocks` to restrict access to your IP

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan Infrastructure

```bash
terraform plan
```

Review the output to see what will be created.

### 5. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted.

### 6. View Outputs

```bash
terraform output
```

This shows all the VPC IDs, subnet IDs, and security group IDs you'll need for EKS.

## What Gets Created

### Infrastructure
- ✅ **1 VPC** with DNS support enabled
- ✅ **2 Public Subnets** across 2 Availability Zones
- ✅ **2 Private Subnets** across 2 Availability Zones  
- ✅ **1 NAT Gateway** for internet access
- ✅ **1 Elastic IP** for the EC2 instance (stable public IP)
- ✅ **1 Internet Gateway**
- ✅ **Route Tables** (1 public, 2 private)
- ✅ **Security Group** for EC2 (SSH, HTTP, HTTPS, MQTT)
- ✅ **VPC Flow Logs** (optional, enabled by default)

### EC2 Instance
- ✅ **Ubuntu 22.04 LTS** operating system
- ✅ **t3.small** instance (2 vCPU, 2GB RAM, 50GB storage) - upgradeable
- ✅ **Docker & Docker Compose** pre-installed
- ✅ **OpenRemote Stack** running in Docker:
  - PostgreSQL (database)
  - Keycloak (authentication)
  - Manager (main application)
- ✅ **Automatic startup** on reboot

## Cost Estimate

**Monthly costs in eu-west-1**:
- EC2 t3.small instance: ~$15/month
- EBS volume (50GB): ~$4/month
- NAT Gateway: ~$33/month
- Data transfer: ~$0-10/month
- VPC/Subnets/Security Groups: Free
- **Total: ~$52-62/month**

### Instance Size Options

| Instance | vCPU | RAM | Monthly Cost | Use Case |
|----------|------|-----|--------------|----------|
| t3.small | 2 | 2GB | ~$15 | Testing, light dev |
| t3.medium | 2 | 4GB | ~$30 | Small production |
| t3.large | 2 | 8GB | ~$60 | Production |

⚠️ **Note**: t3.small has only 2GB RAM. For production use, upgrade to t3.medium or t3.large.

### Cost Optimization

1. **Upgrade for production** (in terraform.tfvars):
   ```hcl
   ec2_instance_type = "t3.medium"  # ~$30/month (2 vCPU, 4GB RAM)
   # or
   ec2_instance_type = "t3.large"   # ~$60/month (2 vCPU, 8GB RAM)
   ```

2. **Stop instance when not in use**:
   ```bash
   aws ec2 stop-instances --instance-ids $(terraform output -raw ec2_instance_id)
   # Only pay for EBS storage (~$4/month) while stopped
   ```

3. **Use Reserved Instance** (40% savings for 1-year commitment)

4. **Use Spot Instance** (70% savings, but can be interrupted)

## Accessing OpenRemote

After deployment completes (~5 minutes), you'll get:

```bash
terraform output openremote_url
# Output: http://54.123.45.67
```

1. **Open the URL** in your browser
2. **Login** with default credentials:
   - Username: `admin`
   - Password: `secret`

⚠️ **Change the password immediately!**

## Managing Your Instance

### SSH Access

```bash
# Get SSH command
terraform output ssh_command

# Connect
ssh -i ~/.ssh/your-key.pem ubuntu@<your-ip>
```

### View OpenRemote Logs

```bash
ssh ubuntu@<your-ip>
cd /opt/openremote
docker-compose logs -f
```

### Restart OpenRemote

```bash
ssh ubuntu@<your-ip>
sudo systemctl restart openremote
```

## Verification

After deployment, verify everything was created:

```bash
# Get VPC ID
terraform output vpc_id

# Check VPC in AWS
aws ec2 describe-vpcs --vpc-ids $(terraform output -raw vpc_id)

# List all subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"

# List all security groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"
```

## Troubleshooting

### Error: Terraform not found
- **Windows**: Install [Terraform for Windows](https://www.terraform.io/downloads.html)
- **Mac**: `brew install terraform`
- **Linux**: Download from [Terraform website](https://www.terraform.io/downloads.html)

### Error: AWS credentials not configured
```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and region
```

### Error: VPC limit exceeded
AWS accounts have a default limit of 5 VPCs per region. Delete unused VPCs or request a limit increase.

### Error: NAT Gateway creation timeout
NAT Gateways take 3-5 minutes to create. Just run `terraform apply` again.

## Next Steps

1. ✅ VPC infrastructure deployed
2. 📝 Update EKS configuration with VPC details
3. 🚀 Deploy EKS cluster: `cd ../kubernetes && ./eks-setup.sh`
4. 🔧 Deploy OpenRemote applications using Helm

## Cleanup

To destroy all resources:

```bash
# On Linux/Mac/Git Bash
./destroy.sh

# On PowerShell
terraform destroy
```

⚠️ **WARNING**: This permanently deletes all VPC resources. Make sure your EKS cluster is deleted first!

## Support

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [OpenRemote Documentation](https://github.com/openremote/openremote)

## Security Recommendations

✅ **Before production**:
1. Restrict `allowed_cidr_blocks` to your office/VPN IP ranges
2. Enable GuardDuty for threat detection
3. Enable AWS Config for compliance monitoring
4. Set up CloudWatch alarms for VPC Flow Logs
5. Implement least-privilege IAM policies
6. Enable MFA for AWS accounts

