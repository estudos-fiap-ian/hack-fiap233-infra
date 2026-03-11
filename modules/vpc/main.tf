###############################################################################
# VPC
###############################################################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

###############################################################################
# Subnets
###############################################################################

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                              = "${var.project_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb"                          = "1"
    "kubernetes.io/cluster/${var.project_name}-eks"   = "shared"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                                              = "${var.project_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb"                 = "1"
    "kubernetes.io/cluster/${var.project_name}-eks"   = "shared"
  }
}

###############################################################################
# Internet Gateway
###############################################################################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

###############################################################################
# NAT Gateway
###############################################################################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.main]
}

###############################################################################
# Route Tables
###############################################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

###############################################################################
# Security Group — EKS Nodes
###############################################################################

resource "aws_security_group" "eks_nodes" {
  name_prefix = "${var.project_name}-eks-nodes-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for EKS worker nodes"

  tags = {
    Name = "${var.project_name}-eks-nodes-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "eks_nodes_from_nlb_users" {
  security_group_id            = aws_security_group.eks_nodes.id
  referenced_security_group_id = aws_security_group.nlb.id
  from_port                    = var.node_port_users
  to_port                      = var.node_port_users
  ip_protocol                  = "tcp"
  description                  = "Allow NLB traffic to users NodePort"
}

resource "aws_vpc_security_group_ingress_rule" "eks_nodes_from_nlb_videos" {
  security_group_id            = aws_security_group.eks_nodes.id
  referenced_security_group_id = aws_security_group.nlb.id
  from_port                    = var.node_port_videos
  to_port                      = var.node_port_videos
  ip_protocol                  = "tcp"
  description                  = "Allow NLB traffic to videos NodePort"
}

resource "aws_vpc_security_group_ingress_rule" "eks_nodes_self" {
  security_group_id            = aws_security_group.eks_nodes.id
  referenced_security_group_id = aws_security_group.eks_nodes.id
  ip_protocol                  = "-1"
  description                  = "Allow node-to-node communication"
}

resource "aws_vpc_security_group_egress_rule" "eks_nodes_all" {
  security_group_id = aws_security_group.eks_nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"
}

###############################################################################
# Security Group — NLB
###############################################################################

resource "aws_security_group" "nlb" {
  name_prefix = "${var.project_name}-nlb-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for internal NLB"

  tags = {
    Name = "${var.project_name}-nlb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "nlb_users" {
  security_group_id = aws_security_group.nlb.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = var.nlb_port_users
  to_port           = var.nlb_port_users
  ip_protocol       = "tcp"
  description       = "Allow VPC traffic to users listener port"
}

resource "aws_vpc_security_group_ingress_rule" "nlb_videos" {
  security_group_id = aws_security_group.nlb.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = var.nlb_port_videos
  to_port           = var.nlb_port_videos
  ip_protocol       = "tcp"
  description       = "Allow VPC traffic to videos listener port"
}

resource "aws_vpc_security_group_egress_rule" "nlb_to_nodes_users" {
  security_group_id            = aws_security_group.nlb.id
  referenced_security_group_id = aws_security_group.eks_nodes.id
  from_port                    = var.node_port_users
  to_port                      = var.node_port_users
  ip_protocol                  = "tcp"
  description                  = "Allow traffic to EKS nodes users NodePort"
}

resource "aws_vpc_security_group_egress_rule" "nlb_to_nodes_videos" {
  security_group_id            = aws_security_group.nlb.id
  referenced_security_group_id = aws_security_group.eks_nodes.id
  from_port                    = var.node_port_videos
  to_port                      = var.node_port_videos
  ip_protocol                  = "tcp"
  description                  = "Allow traffic to EKS nodes videos NodePort"
}

###############################################################################
# Security Group — VPC Link (API Gateway)
###############################################################################

resource "aws_security_group" "vpc_link" {
  name_prefix = "${var.project_name}-vpc-link-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for API Gateway VPC Link"

  tags = {
    Name = "${var.project_name}-vpc-link-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "vpc_link_all" {
  security_group_id = aws_security_group.vpc_link.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"
}

###############################################################################
# Security Group — RDS Users
###############################################################################

resource "aws_security_group" "rds_users" {
  name_prefix = "${var.project_name}-rds-users-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for Users RDS instance"

  tags = {
    Name = "${var.project_name}-rds-users-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_users_from_eks" {
  security_group_id            = aws_security_group.rds_users.id
  referenced_security_group_id = aws_security_group.eks_nodes.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Allow PostgreSQL from EKS nodes"
}

resource "aws_vpc_security_group_egress_rule" "rds_users_all" {
  security_group_id = aws_security_group.rds_users.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

###############################################################################
# Security Group — RDS Videos
###############################################################################

resource "aws_security_group" "rds_videos" {
  name_prefix = "${var.project_name}-rds-videos-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for Videos RDS instance"

  tags = {
    Name = "${var.project_name}-rds-videos-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_videos_from_eks" {
  security_group_id            = aws_security_group.rds_videos.id
  referenced_security_group_id = aws_security_group.eks_nodes.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Allow PostgreSQL from EKS nodes"
}

resource "aws_vpc_security_group_egress_rule" "rds_videos_all" {
  security_group_id = aws_security_group.rds_videos.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
