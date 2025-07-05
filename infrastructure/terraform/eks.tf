# EKS - Documentation: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
# I'm using modules to keep the code clean and easy to understand
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.31"

  cluster_name    = var.eks_cluster_name
  cluster_version = "1.31"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  # During the demo, I will use public access to access the cluster
  cluster_endpoint_public_access  = true

  # If doing demo, add Cidr block to the cluster
  # To get your public ip, you can use the following command:
  # (Invoke-WebRequest -Uri "https://ifconfig.me/ip" -UseBasicParsing).Content
  cluster_endpoint_public_access_cidrs = ["4.210.159.129/32"]

  # I'm using private access only for this assessment so it cannot be accessed from outside the cluster
  # During the demo, I will use public access to access the cluster
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
