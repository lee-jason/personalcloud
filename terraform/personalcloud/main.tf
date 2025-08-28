terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    # Note: bucket name will be set via terraform init -backend-config
    key    = "personalcloud/terraform.tfstate"
    bucket = "personal-glacier-terraform-state"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "glacier_backup" {
  bucket = "${var.bucket_name}"
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
