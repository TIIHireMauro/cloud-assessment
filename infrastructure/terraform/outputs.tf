# This file is used to specify the outputs that are used in the project.
output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  value = module.db.db_instance_endpoint
}

output "rds_db_name" {
  value = module.db.db_instance_name
}
