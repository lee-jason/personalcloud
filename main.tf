terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "glacier_backup" {
  bucket = "${var.bucket_name}-${random_string.bucket_suffix.result}"
}

resource "aws_s3_bucket_public_access_block" "glacier_backup" {
  bucket = aws_s3_bucket.glacier_backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "glacier_backup" {
  bucket = aws_s3_bucket.glacier_backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "glacier_backup" {
  bucket = aws_s3_bucket.glacier_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_user" "backup_user" {
  name = "${var.bucket_name}-backup-user"
}

resource "aws_iam_user_policy" "backup_policy" {
  name = "${var.bucket_name}-backup-policy"
  user = aws_iam_user.backup_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.glacier_backup.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:RestoreObject"
        ]
        Resource = "${aws_s3_bucket.glacier_backup.arn}/*"
      }
    ]
  })
}

resource "aws_iam_access_key" "backup_user_key" {
  user = aws_iam_user.backup_user.name
}