# EKS - Documentation: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
# I'm using modules to keep the code clean and easy to understand
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.eks_cluster_name
  cluster_version = "1.31"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id


  # I'm using private access only for this assessment so it cannot be accessed from outside the cluster
  cluster_endpoint_private_access = true

  # During the demo, I will use public access to access the cluster, but in production, this should be disabled
  # If doing demo, add Cidr block to the cluster, to get your public ip, you can use the following command:
  # (Invoke-WebRequest -Uri "https://ifconfig.me/ip" -UseBasicParsing).Content

  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["4.210.159.129/32"]


  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      # minimum and desired nodes are both 3 to make it highly available and to avoid split-brain (quorum), as a good practice for kubernetes
      desired_size = 3
      # max size is 5 to avoid over-provisioning as this is just a demo (always keep it odd, to avoid split-brain)
      max_size       = 5
      min_size       = 3
      instance_types = ["t3.small"]
      # I'm using spot instances for cost savings purposes and taking the benefit of stateless containers
      capacity_type = "SPOT"
      subnets       = module.vpc.private_subnets
    }
  }


  tags = {
    Project = "TII Assessment - Architecting IoT Solutions"
  }
}
