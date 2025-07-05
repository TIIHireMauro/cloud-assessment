# VPC - Documentation: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
# I'm using modules to keep the code clean and easy to understand
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.1.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.vpc_azs
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets
  database_subnets = var.vpc_database_subnets

  # NAT Gateway is needed for EKS nodes to download Docker images
  enable_nat_gateway     = true
  enable_vpn_gateway     = false
  single_nat_gateway     = true

  enable_dns_hostnames   = true
  enable_dns_support     = true

  create_database_subnet_group      = true
  create_database_subnet_route_table = true

  tags = {
    Project = "TII Assessment - Architecting IoT Solutions"
  }
}
