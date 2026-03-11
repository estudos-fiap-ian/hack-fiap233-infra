variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the VPC Link (private subnets)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for the VPC Link"
  type        = list(string)
}

variable "nlb_listener_users_arn" {
  description = "ARN of the NLB listener for the users service"
  type        = string
}

variable "nlb_listener_videos_arn" {
  description = "ARN of the NLB listener for the videos service"
  type        = string
}

variable "lambda_role_arn" {
  description = "IAM role ARN for the Lambda authorizer (LabRole)"
  type        = string
}

variable "jwt_secret" {
  description = "JWT signing secret for the Lambda authorizer"
  type        = string
  sensitive   = true
}
