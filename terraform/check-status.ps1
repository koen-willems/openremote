# Quick script to check OpenRemote deployment status
# Run this after terraform apply to monitor the installation

param(
    [string]$InstanceIP = ""
)

$ErrorActionPreference = "Continue"

function Write-InfoMessage {
    param([string]$Message)
    Write-Host "ℹ  $Message" -ForegroundColor Blue
}

function Write-SuccessMessage {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-WarningMessage {
    param([string]$Message)
    Write-Host "⚠  $Message" -ForegroundColor Yellow
}

# Get instance IP from terraform if not provided
if (-not $InstanceIP) {
    Write-InfoMessage "Getting instance IP from Terraform..."
    $InstanceIP = terraform output -raw ec2_instance_public_ip
    if (-not $InstanceIP) {
        Write-Host "✗ Could not get instance IP" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-InfoMessage "Checking OpenRemote deployment status on $InstanceIP"
Write-Host "================================================================"
Write-Host ""

# Get instance ID
$InstanceId = terraform output -raw ec2_instance_id

Write-InfoMessage "Instance ID: $InstanceId"
Write-InfoMessage "Instance IP: $InstanceIP"
Write-Host ""

# Check if instance is running
Write-InfoMessage "Checking EC2 instance status..."
$instanceStatus = aws ec2 describe-instance-status --instance-ids $InstanceId --output json 2>&1 | ConvertFrom-Json
if ($instanceStatus.InstanceStatuses.Count -gt 0) {
    $state = $instanceStatus.InstanceStatuses[0].InstanceState.Name
    $systemStatus = $instanceStatus.InstanceStatuses[0].SystemStatus.Status
    $instanceCheckStatus = $instanceStatus.InstanceStatuses[0].InstanceStatus.Status
    
    Write-SuccessMessage "Instance State: $state"
    Write-InfoMessage "System Status: $systemStatus"
    Write-InfoMessage "Instance Status: $instanceCheckStatus"
} else {
    Write-WarningMessage "Instance is still initializing..."
}
Write-Host ""

# Check HTTP connectivity
Write-InfoMessage "Checking web server connectivity..."
try {
    $response = Invoke-WebRequest -Uri "http://$InstanceIP" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    Write-SuccessMessage "Web server is responding (Status: $($response.StatusCode))"
} catch {
    Write-WarningMessage "Web server not responding yet: $($_.Exception.Message)"
}
Write-Host ""

# Get user-data execution status from CloudWatch logs
Write-InfoMessage "Checking deployment progress..."
Write-InfoMessage "To view detailed logs, SSH into the instance and run:"
Write-Host ""
Write-Host "    ssh ubuntu@$InstanceIP" -ForegroundColor Cyan
Write-Host "    sudo tail -f /var/log/user-data.log" -ForegroundColor Cyan
Write-Host ""
Write-Host "Or check Docker container status:" -ForegroundColor Yellow
Write-Host "    ssh ubuntu@$InstanceIP" -ForegroundColor Cyan
Write-Host "    cd /opt/openremote" -ForegroundColor Cyan
Write-Host "    docker-compose ps" -ForegroundColor Cyan
Write-Host "    docker-compose logs -f" -ForegroundColor Cyan
Write-Host ""

# Try to get SSH command
$sshKey = terraform output -raw ssh_command 2>$null
if ($sshKey -and $sshKey -notlike "*No SSH key*") {
    Write-InfoMessage "SSH Command:"
    Write-Host "    $sshKey" -ForegroundColor Cyan
} else {
    Write-InfoMessage "SSH Command (if you have a key):"
    Write-Host "    ssh ubuntu@$InstanceIP" -ForegroundColor Cyan
    Write-Host ""
    Write-InfoMessage "Or use AWS Systems Manager:"
    Write-Host "    aws ssm start-session --target $InstanceId" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "================================================================"
Write-InfoMessage "Deployment typically takes 5-10 minutes after 'terraform apply'"
Write-InfoMessage "Run this script again in a few minutes to check progress"
Write-Host ""
Write-InfoMessage "Once ready, access OpenRemote at:"
Write-Host "    http://$InstanceIP" -ForegroundColor Green
Write-Host ""
Write-InfoMessage "Default credentials: admin / secret"
Write-Host ""

