variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "bucket_name" {
  description = "Base name for the S3 bucket (will have random suffix)"
  type        = string
  default     = "personal-glacier-backup"
}

variable "local_backup_path" {
  description = "Local path to sync with S3"
  type        = string
  default     = "./backup"
}