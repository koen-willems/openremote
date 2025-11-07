# S3 Bucket for OpenRemote Backups

resource "aws_s3_bucket" "openremote_backups" {
  count  = var.enable_s3_backups ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-backups-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-${var.environment}-backups"
  }
}

# Enable versioning for backup protection
resource "aws_s3_bucket_versioning" "openremote_backups" {
  count  = var.enable_s3_backups ? 1 : 0
  bucket = aws_s3_bucket.openremote_backups[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "openremote_backups" {
  count  = var.enable_s3_backups ? 1 : 0
  bucket = aws_s3_bucket.openremote_backups[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "openremote_backups" {
  count  = var.enable_s3_backups ? 1 : 0
  bucket = aws_s3_bucket.openremote_backups[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy to manage old backups
resource "aws_s3_bucket_lifecycle_configuration" "openremote_backups" {
  count  = var.enable_s3_backups ? 1 : 0
  bucket = aws_s3_bucket.openremote_backups[0].id

  rule {
    id     = "delete-old-backups"
    status = "Enabled"

    filter {
      prefix = "backups/"
    }

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# IAM policy for EC2 to access S3 backups
resource "aws_iam_role_policy" "s3_backup_policy" {
  count = var.enable_s3_backups ? 1 : 0
  name  = "${var.project_name}-${var.environment}-s3-backup-policy"
  role  = aws_iam_role.openremote_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.openremote_backups[0].arn,
          "${aws_s3_bucket.openremote_backups[0].arn}/*"
        ]
      }
    ]
  })
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

