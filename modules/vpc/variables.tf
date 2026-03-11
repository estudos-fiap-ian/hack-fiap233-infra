variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for the subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "node_port_users" {
  description = "NodePort for the users service on EKS nodes"
  type        = number
  default     = 30081
}

variable "node_port_videos" {
  description = "NodePort for the videos service on EKS nodes"
  type        = number
  default     = 30082
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
