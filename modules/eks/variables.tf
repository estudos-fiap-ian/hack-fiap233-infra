variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "cluster_role_arn" {
  description = "ARN of the IAM role for the EKS cluster (LabRole)"
  type        = string
}

variable "node_role_arn" {
  description = "ARN of the IAM role for the EKS node group (LabRole)"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the EKS cluster and node group"
  type        = list(string)
}

variable "node_security_group_ids" {
  description = "Additional security group IDs for EKS worker nodes"
  type        = list(string)
}

variable "node_instance_types" {
  description = "EC2 instance types for the node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}
