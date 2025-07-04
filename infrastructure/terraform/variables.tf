# This file is used to specify the variables that are used in the project.
variable "aws_region" {
  description = "AWS region"
  default     = "eu-west-1"
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  default     = "tii-eks-cluster"
}

variable "db_name" {
  description = "RDS database name"
  default     = "tiiassessmentdb"
}

variable "db_username" {
  description = "RDS master username"
  default     = "tiiassessmentuser"
}

variable "db_password" {
  description = "RDS master password"
  sensitive   = true
}