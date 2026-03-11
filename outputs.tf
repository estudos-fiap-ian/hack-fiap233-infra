###############################################################################
# API Gateway
###############################################################################

output "api_gateway_url" {
  description = "Public URL of the API Gateway (entry point for clients)"
  value       = module.api_gateway.api_endpoint
}

###############################################################################
# EKS
###############################################################################

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint URL of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

###############################################################################
# NLB
###############################################################################

output "nlb_dns_name" {
  description = "DNS name of the internal NLB"
  value       = module.nlb.nlb_dns_name
}

###############################################################################
# RDS
###############################################################################

output "rds_users_endpoint" {
  description = "Endpoint of the Users RDS instance"
  value       = module.rds_users.db_endpoint
}

output "rds_videos_endpoint" {
  description = "Endpoint of the Videos RDS instance"
  value       = module.rds_videos.db_endpoint
}

output "rds_users_secret_name" {
  description = "Secrets Manager secret name for Users DB credentials"
  value       = module.rds_users.secret_name
}

output "rds_videos_secret_name" {
  description = "Secrets Manager secret name for Videos DB credentials"
  value       = module.rds_videos.secret_name
}

###############################################################################
# ECR
###############################################################################

output "ecr_users_url" {
  description = "ECR repository URL for the users service"
  value       = aws_ecr_repository.users.repository_url
}

output "ecr_videos_url" {
  description = "ECR repository URL for the videos service"
  value       = aws_ecr_repository.videos.repository_url
}

###############################################################################
# VPC
###############################################################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

###############################################################################
# JWT
###############################################################################

output "jwt_secret_name" {
  description = "Secrets Manager secret name for JWT signing key"
  value       = aws_secretsmanager_secret.jwt_secret.name
}

output "jwt_secret_arn" {
  description = "Secrets Manager secret ARN for JWT signing key"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}
