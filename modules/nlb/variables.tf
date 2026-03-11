variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the NLB (private subnets)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for the NLB"
  type        = list(string)
}

variable "nlb_port_users" {
  description = "NLB listener port for the users service"
  type        = number
  default     = 8081
}

variable "nlb_port_videos" {
  description = "NLB listener port for the videos service"
  type        = number
  default     = 8082
}

variable "node_port_users" {
  description = "NodePort on EKS nodes for the users service"
  type        = number
  default     = 30081
}

variable "node_port_videos" {
  description = "NodePort on EKS nodes for the videos service"
  type        = number
  default     = 30082
}

variable "node_group_asg_name" {
  description = "Auto Scaling Group name from the EKS node group"
  type        = string
}
