# OpenRemote Diagnostic Script
# Checks EC2 instance and Docker container status

param(
    [string]$InstanceId = ""
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

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

# Get instance ID from terraform if not provided
if (-not $InstanceId) {
    Write-InfoMessage "Getting instance ID from Terraform..."
    $InstanceId = terraform output -raw ec2_instance_id
    if (-not $InstanceId) {
        Write-ErrorMessage "Could not get instance ID"
        exit 1
    }
}

$InstanceIP = terraform output -raw ec2_instance_public_ip

Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  OpenRemote Diagnostic Report" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-InfoMessage "Instance ID: $InstanceId"
Write-InfoMessage "Instance IP: $InstanceIP"
Write-Host ""

# 1. Check EC2 Instance Status
Write-Host "1️⃣  Checking EC2 Instance Status..." -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────"
$instanceInfo = aws ec2 describe-instances --instance-ids $InstanceId --region eu-west-1 --output json | ConvertFrom-Json
$instance = $instanceInfo.Reservations[0].Instances[0]

$state = $instance.State.Name
$launchTime = $instance.LaunchTime

switch ($state) {
    "running" {
        Write-SuccessMessage "Instance State: $state"
        $uptime = (Get-Date) - [datetime]$launchTime
        Write-InfoMessage "Uptime: $($uptime.Hours) hours, $($uptime.Minutes) minutes"
    }
    default {
        Write-ErrorMessage "Instance State: $state (Expected: running)"
        Write-InfoMessage "Instance needs to be running. Start it with: aws ec2 start-instances --instance-ids $InstanceId"
        exit 1
    }
}
Write-Host ""

# 2. Check System Status
Write-Host "2️⃣  Checking System Status..." -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────"
$statusInfo = aws ec2 describe-instance-status --instance-ids $InstanceId --region eu-west-1 --output json | ConvertFrom-Json

if ($statusInfo.InstanceStatuses.Count -gt 0) {
    $systemStatus = $statusInfo.InstanceStatuses[0].SystemStatus.Status
    $instanceStatus = $statusInfo.InstanceStatuses[0].InstanceStatus.Status
    
    if ($systemStatus -eq "ok") {
        Write-SuccessMessage "System Status: $systemStatus"
    } else {
        Write-WarningMessage "System Status: $systemStatus (waiting for initialization...)"
    }
    
    if ($instanceStatus -eq "ok") {
        Write-SuccessMessage "Instance Status: $instanceStatus"
    } else {
        Write-WarningMessage "Instance Status: $instanceStatus (waiting for initialization...)"
    }
} else {
    Write-WarningMessage "Instance status checks not yet available (instance just started)"
}
Write-Host ""

# 3. Check HTTP Connectivity
Write-Host "3️⃣  Checking HTTP Connectivity..." -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────"
try {
    $response = Invoke-WebRequest -Uri "http://$InstanceIP" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    Write-SuccessMessage "HTTP Server responding: Status $($response.StatusCode)"
    
    if ($response.Content -like "*OpenRemote*" -or $response.Content -like "*Keycloak*") {
        Write-SuccessMessage "OpenRemote/Keycloak content detected!"
    } else {
        Write-WarningMessage "Server responding but content doesn't look like OpenRemote"
        Write-InfoMessage "This might mean containers are still starting..."
    }
} catch {
    Write-ErrorMessage "HTTP server not responding: $($_.Exception.Message)"
    Write-InfoMessage "This usually means Docker containers haven't started yet"
}
Write-Host ""

# 4. Check User Data Execution
Write-Host "4️⃣  Installation Progress Check..." -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────"
Write-InfoMessage "User-data script installs Docker and OpenRemote"
Write-InfoMessage "This takes 5-10 minutes after instance launch"
Write-Host ""

# Check console output (limited to last few lines)
Write-InfoMessage "Fetching console output (this may take a moment)..."
try {
    $consoleOutput = aws ec2 get-console-output --instance-id $InstanceId --region eu-west-1 --output json 2>&1 | ConvertFrom-Json
    if ($consoleOutput.Output) {
        $outputLines = $consoleOutput.Output -split "`n"
        $lastLines = $outputLines | Select-Object -Last 20
        
        Write-InfoMessage "Last 20 lines of console output:"
        Write-Host "────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        foreach ($line in $lastLines) {
            Write-Host $line -ForegroundColor Gray
        }
        Write-Host "────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""
        
        if ($consoleOutput.Output -match "Installation Complete") {
            Write-SuccessMessage "User-data script completed!"
        } else {
            Write-WarningMessage "User-data script still running or not completed"
            Write-InfoMessage "Wait a few more minutes and try again"
        }
    } else {
        Write-WarningMessage "Console output not yet available"
    }
} catch {
    Write-WarningMessage "Could not retrieve console output: $_"
}
Write-Host ""

# 5. Recommendations
Write-Host "5️⃣  Recommendations..." -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────"

if ($state -eq "running") {
    $uptimeMinutes = ((Get-Date) - [datetime]$launchTime).TotalMinutes
    
    if ($uptimeMinutes -lt 10) {
        Write-WarningMessage "Instance launched $([math]::Round($uptimeMinutes, 1)) minutes ago"
        Write-InfoMessage "OpenRemote typically takes 5-10 minutes to fully start"
        Write-InfoMessage "⏳ Please wait $([math]::Round(10 - $uptimeMinutes, 0)) more minutes and try again"
        Write-Host ""
        Write-InfoMessage "What's happening:"
        Write-Host "  • Docker is being installed" -ForegroundColor Gray
        Write-Host "  • Docker images are being downloaded (~1-2 GB)" -ForegroundColor Gray
        Write-Host "  • PostgreSQL is initializing" -ForegroundColor Gray
        Write-Host "  • Keycloak is starting (needs PostgreSQL first)" -ForegroundColor Gray
        Write-Host "  • Manager is starting (needs Keycloak first)" -ForegroundColor Gray
    } else {
        Write-ErrorMessage "Instance has been running for $([math]::Round($uptimeMinutes, 1)) minutes"
        Write-InfoMessage "OpenRemote should be ready by now. There might be an issue."
        Write-Host ""
        Write-InfoMessage "Next steps to debug:"
        Write-Host ""
        Write-Host "  Option 1: Use EC2 Instance Connect (browser-based SSH)" -ForegroundColor Cyan
        Write-Host "    1. Go to: https://console.aws.amazon.com/ec2/" -ForegroundColor Cyan
        Write-Host "    2. Select instance: $InstanceId" -ForegroundColor Cyan
        Write-Host "    3. Click 'Connect' > 'EC2 Instance Connect'" -ForegroundColor Cyan
        Write-Host "    4. Click 'Connect'" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Option 2: Install AWS SSM Plugin for command-line access" -ForegroundColor Cyan
        Write-Host "    Download: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html" -ForegroundColor Cyan
        Write-Host ""
        Write-InfoMessage "Once connected, run these commands:"
        Write-Host "    sudo tail -f /var/log/user-data.log    # Check installation log" -ForegroundColor Green
        Write-Host "    cd /opt/openremote" -ForegroundColor Green
        Write-Host "    docker-compose ps                       # Check container status" -ForegroundColor Green
        Write-Host "    docker-compose logs -f                  # View container logs" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-InfoMessage "Run this script again in a few minutes: .\diagnose.ps1"
Write-Host ""

