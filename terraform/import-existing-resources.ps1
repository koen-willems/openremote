# Script to import existing AWS resources into Terraform state
# Run this from the terraform directory

Write-Host "Importing existing AWS resources into Terraform state..." -ForegroundColor Green

# Set variables (adjust if needed)
$PROJECT_NAME = "openremote"
$ENVIRONMENT = "dev"
$ACCOUNT_ID = "957207443716"

# Import IAM Role for EC2
Write-Host "`nImporting IAM Role: openremote-dev-ec2-role" -ForegroundColor Yellow
terraform import aws_iam_role.openremote_ec2 "openremote-dev-ec2-role"

# Import CloudWatch Log Group (only if VPC flow logs are enabled)
if ($env:ENABLE_VPC_FLOW_LOGS -ne "false") {
    Write-Host "`nImporting CloudWatch Log Group: /aws/vpc/openremote-dev" -ForegroundColor Yellow
    terraform import 'aws_cloudwatch_log_group.flow_log[0]' "/aws/vpc/openremote-dev"
    
    Write-Host "`nImporting IAM Role: openremote-dev-flow-log-role" -ForegroundColor Yellow
    terraform import 'aws_iam_role.flow_log[0]' "openremote-dev-flow-log-role"
}

# Import S3 Bucket (only if S3 backups are enabled)
if ($env:ENABLE_S3_BACKUPS -ne "false") {
    Write-Host "`nImporting S3 Bucket: openremote-dev-backups-$ACCOUNT_ID" -ForegroundColor Yellow
    terraform import 'aws_s3_bucket.openremote_backups[0]' "openremote-dev-backups-$ACCOUNT_ID"
}

Write-Host "`nImport complete! Run 'terraform plan' to verify." -ForegroundColor Green

