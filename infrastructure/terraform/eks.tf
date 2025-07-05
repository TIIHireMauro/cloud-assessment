# EKS - Documentation: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
# I'm using modules to keep the code clean and easy to understand
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.31"

  cluster_name    = var.eks_cluster_name
  cluster_version = "1.31"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      desired_size = 3
      max_size     = 4
      min_size     = 3
      instance_types = ["t3.small"]
      capacity_type  = "SPOT"
      subnets        = module.vpc.private_subnets
    }
  }

  tags = {
    Project = "TII Assessment - Architecting IoT Solutions"
  }
}
