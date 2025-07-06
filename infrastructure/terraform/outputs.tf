# Important outputs for the project (testing purposes)
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  value = module.rds.db_instance_endpoint
}

output "rds_master_user_secret_arn" {
  value = module.rds.db_instance_master_user_secret_arn
}


output "lambda_simulator_arn" {
  value = aws_lambda_function.iot_simulator.arn
}

output "iot_core_thing_name" {
  value = aws_iot_thing.sensor.name
}

output "iot_core_thing_arn" {
  value = aws_iot_thing.sensor.arn
}

data "aws_iot_endpoint" "iot_endpoint" {
  endpoint_type = "iot:Data-ATS"
}

output "iot_core_endpoint" {
  value = data.aws_iot_endpoint.iot_endpoint.endpoint_address
}

output "backend_sa_role_arn" {
  value = module.backend_irsa.iam_role_arn
  description = "ARN of the IAM role for backend service account"
}

output "backend_iam_role_arn" {
  value = module.backend_irsa.iam_role_arn
  description = "ARN of the IAM role for backend service account (for ESO)"
}

# ECR Repository outputs
output "backend_ecr_repository_url" {
  value = module.ecr.repository_url
  description = "URL of the backend ECR repository"
}