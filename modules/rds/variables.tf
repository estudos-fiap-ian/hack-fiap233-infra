variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "service_name" {
  description = "Name of the microservice (e.g. users, videos)"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the RDS subnet group (private subnets)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for the RDS instance"
  type        = list(string)
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Name of the database to create"
  type        = string
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "dbadmin"
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.6"
}
