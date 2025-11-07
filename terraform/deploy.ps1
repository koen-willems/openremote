# OpenRemote EC2 Infrastructure Deployment Script (PowerShell)
# This script deploys OpenRemote on EC2 using Terraform on Windows

param(
    [switch]$SkipChecks = $false
)

# Set error action but allow function definitions
$ErrorActionPreference = "Stop"

# Ensure we're in the script directory
Set-Location $PSScriptRoot

# Colors for output - Define as script-level functions
function global:Write-InfoMessage {
    param([string]$Message)
    Write-Host "ℹ  $Message" -ForegroundColor Blue
}

function global:Write-SuccessMessage {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function global:Write-WarningMessage {
    param([string]$Message)
    Write-Host "⚠  $Message" -ForegroundColor Yellow
}

function global:Write-ErrorMessage {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

# Check prerequisites
function Check-Prerequisites {
    Write-InfoMessage "Checking prerequisites..."
    
    # Check Terraform
    $tfCommand = Get-Command terraform -ErrorAction SilentlyContinue
    if ($tfCommand) {
        $tfVersion = & terraform --version 2>&1 | Select-Object -First 1
        Write-SuccessMessage "Terraform found: $tfVersion"
    } else {
        Write-ErrorMessage "Terraform is not installed. Please install it from https://www.terraform.io/downloads.html"
        exit 1
    }
    
    # Check AWS CLI
    $awsCommand = Get-Command aws -ErrorAction SilentlyContinue
    if ($awsCommand) {
        $awsVersion = & aws --version 2>&1
        Write-SuccessMessage "AWS CLI found: $awsVersion"
    } else {
        Write-ErrorMessage "AWS CLI is not installed. Please install it from https://aws.amazon.com/cli/"
        exit 1
    }
    
    # Check AWS credentials
    try {
        $identity = & aws sts get-caller-identity --output json 2>&1 | ConvertFrom-Json
        if ($identity.Account) {
            Write-SuccessMessage "AWS credentials valid. Account: $($identity.Account)"
            Write-InfoMessage "Identity: $($identity.Arn)"
        } else {
            throw "Invalid response from AWS"
        }
    } catch {
        Write-ErrorMessage "AWS credentials are not configured or invalid"
        Write-InfoMessage "Please run: aws configure"
        Write-InfoMessage "Or set: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN"
        exit 1
    }
}

# Check if tfvars exists
function Check-Config {
    if (-not (Test-Path "terraform.tfvars")) {
        Write-WarningMessage "terraform.tfvars not found"
        Write-InfoMessage "Creating from example file..."
        Copy-Item "terraform.tfvars.example" "terraform.tfvars"
        Write-SuccessMessage "Created terraform.tfvars"
        Write-WarningMessage "Please review and customize terraform.tfvars before proceeding"
        Write-InfoMessage "Particularly, review these settings:"
        Write-InfoMessage "  - aws_region"
        Write-InfoMessage "  - project_name"
        Write-InfoMessage "  - environment"
        Write-InfoMessage "  - allowed_cidr_blocks (restrict to your IP for security)"
        Write-Host ""
        
        # Open file in default editor
        Start-Process "terraform.tfvars"
        
        $continue = Read-Host "Press Enter after reviewing terraform.tfvars to continue, or type 'exit' to quit"
        if ($continue -eq "exit") {
            Write-InfoMessage "Deployment cancelled"
            exit 0
        }
    } else {
        Write-SuccessMessage "terraform.tfvars found"
    }
}

# Initialize Terraform
function Initialize-Terraform {
    Write-InfoMessage "Initializing Terraform..."
    terraform init
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Terraform initialization failed"
        exit 1
    }
    Write-SuccessMessage "Terraform initialized"
}

# Run terraform plan
function Plan-Infrastructure {
    Write-InfoMessage "Planning infrastructure changes..."
    terraform plan -out=tfplan
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Terraform plan failed"
        exit 1
    }
    Write-SuccessMessage "Plan created successfully"
    Write-Host ""
    Write-InfoMessage "Review the plan above. This will create:"
    Write-InfoMessage "  - 1 VPC"
    Write-InfoMessage "  - 2 Public subnets (across 2 AZs)"
    Write-InfoMessage "  - 2 Private subnets (across 2 AZs)"
    Write-InfoMessage "  - 1 NAT Gateway"
    Write-InfoMessage "  - 1 Internet Gateway"
    Write-InfoMessage "  - 1 EC2 Instance with OpenRemote"
    Write-InfoMessage "  - Security Groups"
    Write-Host ""
}

# Apply terraform plan
function Apply-Infrastructure {
    $confirm = Read-Host "Do you want to apply these changes? (yes/no)"
    if ($confirm -ne "yes") {
        Write-WarningMessage "Deployment cancelled"
        if (Test-Path "tfplan") {
            Remove-Item "tfplan"
        }
        exit 0
    }
    
    Write-InfoMessage "Applying infrastructure changes..."
    terraform apply tfplan
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Terraform apply failed"
        exit 1
    }
    if (Test-Path "tfplan") {
        Remove-Item "tfplan"
    }
    Write-SuccessMessage "Infrastructure deployed successfully!"
}

# Show outputs
function Show-Outputs {
    Write-Host ""
    Write-InfoMessage "Infrastructure Details:"
    Write-Host ""
    terraform output
    Write-Host ""
    Write-SuccessMessage "OpenRemote is deploying on your EC2 instance!"
    Write-Host ""
    Write-InfoMessage "Next steps:"
    Write-InfoMessage "  1. Wait ~5 minutes for OpenRemote to fully start"
    Write-InfoMessage "  2. Access OpenRemote at the URL shown above"
    Write-InfoMessage "  3. Login with: admin / secret (change password immediately!)"
    Write-Host ""
    Write-InfoMessage "To get outputs later, run: terraform output"
    Write-InfoMessage "To view logs: ssh into instance and run: cd /opt/openremote && docker-compose logs -f"
}

# Save outputs to file
function Save-Outputs {
    Write-InfoMessage "Saving outputs to terraform-outputs.json..."
    terraform output -json | Out-File -FilePath "terraform-outputs.json" -Encoding utf8
    Write-SuccessMessage "Outputs saved to terraform-outputs.json"
}

# Main execution
function Main {
    Write-Host ""
    Write-InfoMessage "OpenRemote EC2 Infrastructure Deployment"
    Write-Host "=========================================="
    Write-Host ""
    
    if (-not $SkipChecks) {
        Check-Prerequisites
        Write-Host ""
    }
    
    Check-Config
    Write-Host ""
    
    Initialize-Terraform
    Write-Host ""
    
    Plan-Infrastructure
    Write-Host ""
    
    Apply-Infrastructure
    Write-Host ""
    
    Show-Outputs
    
    Save-Outputs
    Write-Host ""
    
    Write-SuccessMessage "Deployment complete!"
    Write-Host ""
    Write-InfoMessage "Estimated monthly cost: ~`$67-77 (t3.medium + NAT Gateway + storage)"
    Write-InfoMessage "To check status: .\check-status.ps1"
}

# Run main function
try {
    # Ensure all functions are loaded
    if (-not (Get-Command Write-SuccessMessage -ErrorAction SilentlyContinue)) {
        Write-Host "✗ Error: Script functions not loaded properly" -ForegroundColor Red
        Write-Host "Try running: . .\deploy.ps1" -ForegroundColor Yellow
        exit 1
    }
    
    Main
} catch {
    Write-Host "✗ An error occurred: $_" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
    exit 1
}

