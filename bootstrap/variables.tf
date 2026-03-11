variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "hack-fiap233-tfstate"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "hack-fiap233"
}
