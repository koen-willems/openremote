# OpenRemote VPC Infrastructure Destruction Script (PowerShell)
# WARNING: This will destroy all VPC resources created by Terraform

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Info {
    param([string]$Message)
    Write-Host "ℹ  $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

# Warning banner
function Show-Warning {
    Write-Host ""
    Write-Error "╔════════════════════════════════════════════════════════════╗"
    Write-Error "║                     ⚠  WARNING ⚠                          ║"
    Write-Error "║                                                            ║"
    Write-Error "║  This will PERMANENTLY DELETE all VPC infrastructure      ║"
    Write-Error "║  created by Terraform, including:                         ║"
    Write-Error "║                                                            ║"
    Write-Error "║  • VPC and all subnets                                    ║"
    Write-Error "║  • NAT Gateways and Elastic IPs                           ║"
    Write-Error "║  • Internet Gateway                                       ║"
    Write-Error "║  • Security Groups                                        ║"
    Write-Error "║  • Route Tables                                           ║"
    Write-Error "║  • VPC Flow Logs                                          ║"
    Write-Error "║                                                            ║"
    Write-Error "║  This action CANNOT be undone!                            ║"
    Write-Error "╚════════════════════════════════════════════════════════════╝"
    Write-Host ""
}

# Check if EKS cluster exists
function Check-EksCluster {
    Write-Info "Checking for existing EKS clusters..."
    
    if (-not (Test-Path "terraform.tfvars")) {
        Write-Warning "terraform.tfvars not found, skipping EKS check"
        return
    }
    
    try {
        $clusterName = (Select-String -Path "terraform.tfvars" -Pattern '^cluster_name\s*=\s*"([^"]+)"' | 
                        ForEach-Object { $_.Matches.Groups[1].Value })
        $awsRegion = (Select-String -Path "terraform.tfvars" -Pattern '^aws_region\s*=\s*"([^"]+)"' | 
                      ForEach-Object { $_.Matches.Groups[1].Value })
        
        if (-not $awsRegion) {
            $awsRegion = "eu-west-1"
        }
        
        if ($clusterName) {
            try {
                $cluster = aws eks describe-cluster --name $clusterName --region $awsRegion --output json 2>&1 | ConvertFrom-Json
                if ($cluster.cluster) {
                    Write-Error "EKS cluster '$clusterName' is still running!"
                    Write-Error "You must delete the EKS cluster BEFORE destroying the VPC"
                    Write-Info "Run: cd ..\kubernetes; .\eks-cleanup.sh (in Git Bash or WSL)"
                    exit 1
                }
            } catch {
                Write-Success "No active EKS cluster found"
            }
        }
    } catch {
        Write-Warning "Could not check for EKS cluster: $_"
    }
}

# Show what will be destroyed
function Show-Plan {
    Write-Info "Showing resources that will be destroyed..."
    Write-Host ""
    terraform plan -destroy
    Write-Host ""
}

# Confirm destruction
function Confirm-Destruction {
    Write-Host ""
    Write-Warning "You are about to destroy all VPC infrastructure"
    $confirm1 = Read-Host "Type 'yes' to confirm destruction"
    
    if ($confirm1 -ne "yes") {
        Write-Info "Destruction cancelled"
        exit 0
    }
    
    Write-Warning "Are you ABSOLUTELY sure? This cannot be undone!"
    $confirm2 = Read-Host "Type 'yes' again to proceed"
    
    if ($confirm2 -ne "yes") {
        Write-Info "Destruction cancelled"
        exit 0
    }
}

# Destroy infrastructure
function Destroy-Infrastructure {
    Write-Info "Destroying infrastructure..."
    Write-Host ""
    
    terraform destroy -auto-approve
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform destroy failed"
        exit 1
    }
    
    Write-Success "Infrastructure destroyed successfully"
}

# Cleanup local files
function Cleanup-Files {
    Write-Info "Cleaning up local files..."
    
    if (Test-Path "tfplan") {
        Remove-Item "tfplan"
    }
    if (Test-Path "terraform-outputs.json") {
        Remove-Item "terraform-outputs.json"
    }
    
    Write-Success "Local files cleaned up"
}

# Main execution
function Main {
    # Change to script directory
    Set-Location $PSScriptRoot
    
    Show-Warning
    
    Check-EksCluster
    Write-Host ""
    
    Show-Plan
    
    Confirm-Destruction
    Write-Host ""
    
    Destroy-Infrastructure
    Write-Host ""
    
    Cleanup-Files
    Write-Host ""
    
    Write-Success "All VPC resources have been destroyed"
    Write-Info "You can now redeploy using .\deploy.ps1 if needed"
}

# Run main function
try {
    Main
} catch {
    Write-Error "An error occurred: $_"
    exit 1
}

