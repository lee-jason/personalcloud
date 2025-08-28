output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.glacier_backup.bucket
}

output "bucket_region" {
  description = "Region of the S3 bucket"
  value       = var.aws_region
}

output "iam_access_key_id" {
  description = "Access key ID for backup user"
  value       = aws_iam_access_key.backup_user_key.id
}

output "iam_secret_access_key" {
  description = "Secret access key for backup user"
  value       = aws_iam_access_key.backup_user_key.secret
  sensitive   = true
}