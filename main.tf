terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # The bucket must exist before running terraform init.
  # Create it first by running: cd bootstrap && terraform init && terraform apply
  backend "s3" {
    bucket = "hack-fiap233-tfstate"
    key    = "infra/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

###############################################################################
# LabRole — used everywhere instead of creating IAM roles (AWS Academy)
###############################################################################

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

###############################################################################
# VPC
###############################################################################

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  node_port_users      = var.node_port_users
  node_port_videos     = var.node_port_videos
  nlb_port_users       = var.nlb_port_users
  nlb_port_videos      = var.nlb_port_videos
}

###############################################################################
# EKS
###############################################################################

module "eks" {
  source = "./modules/eks"

  project_name            = var.project_name
  cluster_role_arn        = data.aws_iam_role.lab_role.arn
  node_role_arn           = data.aws_iam_role.lab_role.arn
  subnet_ids              = module.vpc.private_subnet_ids
  node_security_group_ids = [module.vpc.sg_eks_nodes_id]
  node_instance_types     = var.node_instance_types
  node_desired_size       = var.node_desired_size
  node_min_size           = var.node_min_size
  node_max_size           = var.node_max_size
  kubernetes_version      = var.kubernetes_version
}

###############################################################################
# NLB
###############################################################################

module "nlb" {
  source = "./modules/nlb"

  project_name         = var.project_name
  vpc_id               = module.vpc.vpc_id
  subnet_ids           = module.vpc.private_subnet_ids
  security_group_ids   = [module.vpc.sg_nlb_id]
  nlb_port_users       = var.nlb_port_users
  nlb_port_videos      = var.nlb_port_videos
  node_port_users      = var.node_port_users
  node_port_videos     = var.node_port_videos
  node_group_asg_name  = module.eks.node_group_asg_name
}

###############################################################################
# JWT Secret (for Lambda Authorizer + Users service)
###############################################################################

resource "random_password" "jwt_secret" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name = "${var.project_name}/jwt-secret"
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}

###############################################################################
# API Gateway
###############################################################################

module "api_gateway" {
  source = "./modules/api_gateway"

  project_name            = var.project_name
  subnet_ids              = module.vpc.private_subnet_ids
  security_group_ids      = [module.vpc.sg_vpc_link_id]
  nlb_listener_users_arn  = module.nlb.listener_users_arn
  nlb_listener_videos_arn = module.nlb.listener_videos_arn
  lambda_role_arn         = data.aws_iam_role.lab_role.arn
  jwt_secret              = random_password.jwt_secret.result
}

###############################################################################
# ECR Repositories
###############################################################################

resource "aws_ecr_repository" "users" {
  name         = "${var.project_name}-users"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "${var.project_name}-users"
  }
}

resource "aws_ecr_repository" "videos" {
  name         = "${var.project_name}-videos"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "${var.project_name}-videos"
  }
}

###############################################################################
# RDS — Users
###############################################################################

module "rds_users" {
  source = "./modules/rds"

  project_name       = var.project_name
  service_name       = "users"
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.sg_rds_users_id]
  instance_class     = var.rds_instance_class
  allocated_storage  = var.rds_allocated_storage
  db_name            = "usersdb"
  db_username        = var.rds_db_username
  engine_version     = var.rds_engine_version
}

###############################################################################
# RDS — Videos
###############################################################################

module "rds_videos" {
  source = "./modules/rds"

  project_name       = var.project_name
  service_name       = "videos"
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.sg_rds_videos_id]
  instance_class     = var.rds_instance_class
  allocated_storage  = var.rds_allocated_storage
  db_name            = "videosdb"
  db_username        = var.rds_db_username
  engine_version     = var.rds_engine_version
}
