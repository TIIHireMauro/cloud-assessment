# This file is used to specify the variables that are used in the project.

# General variables
variable "aws_region" {
  description = "AWS region"
  default     = "eu-west-1"
}

# VPC variables
variable "vpc_cidr" {
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

variable "vpc_name" {
  description = "VPC name"
  default     = "tii-vpc"
}

variable "vpc_azs" {
  description = "VPC availability zones (3 for production is recommended in EKS to avoid split-brain)"
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "vpc_private_subnets" {
  description = "VPC private subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "vpc_public_subnets" {
  description = "VPC public subnets"
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "vpc_database_subnets" {
  description = "VPC database subnets"
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

# EKS variables
variable "eks_cluster_name" {
  description = "EKS cluster name"
  default     = "tii-eks-cluster"
}

# RDS variables
variable "db_name" {
  description = "RDS database name"
  default     = "tiiassessmentdb"
}

variable "db_username" {
  description = "RDS master username"
  default     = "tiiassessmentuser"
}

