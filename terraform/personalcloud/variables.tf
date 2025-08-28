variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Base name for the S3 bucket (will have random suffix)"
  type        = string
  default     = "personal-glacier-cloud"
}

variable "terraform_state_bucket" {
  description = "Name of the S3 bucket to store Terraform state"
  type        = string
  default    = "personal-glacier-terraform-state"
}

variable "local_backup_path" {
  description = "Local path to sync with S3"
  type        = string
  default     = "./backup"
}

