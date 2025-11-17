# Script to manually delete existing AWS resources that conflict with Terraform
# Run this from the terraform directory
# WARNING: This will permanently delete resources and their data!

Write-Host "WARNING: This will delete AWS resources!" -ForegroundColor Red
Write-Host "Press Ctrl+C to cancel, or Enter to continue..." -ForegroundColor Yellow
Read-Host

$PROJECT_NAME = "openremote"
$ENVIRONMENT = "dev"
$ACCOUNT_ID = "957207443716"

Write-Host "`nDeleting existing resources..." -ForegroundColor Yellow

# Delete IAM Role for EC2 (must detach policies first)
Write-Host "`n1. Detaching policies from IAM Role: openremote-dev-ec2-role" -ForegroundColor Cyan
$roleName = "openremote-dev-ec2-role"
$policies = aws iam list-attached-role-policies --role-name $roleName --query 'AttachedPolicies[*].PolicyArn' --output text
foreach ($policy in $policies) {
    if ($policy) {
        Write-Host "  Detaching policy: $policy"
        aws iam detach-role-policy --role-name $roleName --policy-arn $policy
    }
}
$inlinePolicies = aws iam list-role-policies --role-name $roleName --query 'PolicyNames' --output text
foreach ($policy in $inlinePolicies) {
    if ($policy) {
        Write-Host "  Deleting inline policy: $policy"
        aws iam delete-role-policy --role-name $roleName --policy-name $policy
    }
}
Write-Host "  Deleting IAM Role: $roleName"
aws iam delete-role --role-name $roleName

# Delete CloudWatch Log Group
Write-Host "`n2. Deleting CloudWatch Log Group: /aws/vpc/openremote-dev" -ForegroundColor Cyan
aws logs delete-log-group --log-group-name "/aws/vpc/openremote-dev" 2>$null

# Delete IAM Role for Flow Logs
Write-Host "`n3. Deleting IAM Role: openremote-dev-flow-log-role" -ForegroundColor Cyan
$flowLogRole = "openremote-dev-flow-log-role"
$flowPolicies = aws iam list-attached-role-policies --role-name $flowLogRole --query 'AttachedPolicies[*].PolicyArn' --output text 2>$null
foreach ($policy in $flowPolicies) {
    if ($policy) {
        aws iam detach-role-policy --role-name $flowLogRole --policy-arn $policy
    }
}
aws iam delete-role --role-name $flowLogRole 2>$null

# Delete S3 Bucket (must be empty first)
Write-Host "`n4. Deleting S3 Bucket: openremote-dev-backups-$ACCOUNT_ID" -ForegroundColor Cyan
$bucketName = "openremote-dev-backups-$ACCOUNT_ID"
Write-Host "  Emptying bucket..."
aws s3 rm s3://$bucketName --recursive 2>$null
Write-Host "  Deleting bucket..."
aws s3api delete-bucket --bucket $bucketName 2>$null

Write-Host "`nDeletion complete! You can now run the GitHub Actions workflow." -ForegroundColor Green

