# This file is used to specify the main module that is used in the project.

# VPC - Documentation: https://registry.terraform-aws-modules/vpc/aws/5.1.0
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.1.0"

  name = "tii-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  database_subnets = ["10.0.11.0/24", "10.0.12.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  create_database_subnet_group = true
}

# EKS Cluster - Documentation: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.31"

  cluster_name    = var.eks_cluster_name
  cluster_version = "1.31"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      desired_size = 2
      max_size     = 3
      min_size     = 2
      instance_types = ["t3.small"]
      capacity_type  = "SPOT"
    } 
  } 
}

# RDS PostgreSQL - Documentation: https://registry.terraform.io/modules/terraform-aws-modules/rds/aws/6.5.0
module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.5.0"

  identifier = "tii-assessment-db"
  engine     = "postgres"
  engine_version = "16.4"
  instance_class = "db.t3.small"
  allocated_storage = 10
  family = "postgres16"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [module.vpc.default_security_group_id]
  db_subnet_group_name   = module.vpc.database_subnet_group_name

  multi_az = true
  publicly_accessible = false
  skip_final_snapshot = true
}
