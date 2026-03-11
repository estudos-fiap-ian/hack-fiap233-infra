output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "sg_eks_nodes_id" {
  description = "Security group ID for EKS worker nodes"
  value       = aws_security_group.eks_nodes.id
}

output "sg_nlb_id" {
  description = "Security group ID for the internal NLB"
  value       = aws_security_group.nlb.id
}

output "sg_vpc_link_id" {
  description = "Security group ID for the API Gateway VPC Link"
  value       = aws_security_group.vpc_link.id
}

output "sg_rds_users_id" {
  description = "Security group ID for the Users RDS instance"
  value       = aws_security_group.rds_users.id
}

output "sg_rds_videos_id" {
  description = "Security group ID for the Videos RDS instance"
  value       = aws_security_group.rds_videos.id
}
