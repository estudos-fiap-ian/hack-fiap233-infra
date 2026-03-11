###############################################################################
# EKS Cluster
###############################################################################

resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-eks"
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  tags = {
    Name = "${var.project_name}-eks"
  }
}

###############################################################################
# EKS Access Entry — grants the caller (voclabs) cluster admin access
###############################################################################

data "aws_caller_identity" "current" {}

locals {
  # Convert assumed-role ARN to IAM role ARN
  # From: arn:aws:sts::ACCOUNT:assumed-role/ROLE_NAME/session
  # To:   arn:aws:iam::ACCOUNT:role/ROLE_NAME
  caller_role_name = split("/", data.aws_caller_identity.current.arn)[1]
  caller_role_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.caller_role_name}"
}

resource "aws_eks_access_entry" "caller" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = local.caller_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "caller_admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = local.caller_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.caller]
}

###############################################################################
# Launch Template (attaches cluster SG + custom node SGs)
###############################################################################

resource "aws_launch_template" "eks_nodes" {
  name_prefix = "${var.project_name}-eks-node-"

  vpc_security_group_ids = concat(
    [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id],
    var.node_security_group_ids
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-eks-node"
    }
  }
}

###############################################################################
# Managed Node Group
###############################################################################

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-node-group"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  tags = {
    Name = "${var.project_name}-node-group"
  }
}
