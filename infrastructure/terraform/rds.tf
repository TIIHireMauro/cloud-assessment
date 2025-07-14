# RDS - Documentation: https://registry.terraform.io/modules/terraform-aws-modules/rds/aws/latest
# I'm using modules to keep the code clean and easy to understand

# Security group para o RDS
resource "aws_security_group" "rds" {
  name_prefix = "rds-"
  vpc_id      = module.vpc.vpc_id

  # Allow ingress from EKS cluster
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.cluster_security_group_id]
  }

  # Allow ingress from EKS nodes
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-security-group"
  }
}

# PostgreSQL Parameter Group
resource "aws_db_parameter_group" "postgres" {
  family = "postgres16"
  name   = "tii-assessment-postgres16"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = {
    Name = "tii-assessment-postgres-params"
  }
}

# Data source to get existing secret (created by test-cloud.ps1 script)
# This is for demo purposes only. In production, RDS should manage its own password
data "aws_secretsmanager_secret" "rds_password" {
  name = "tii-assessment/db-password"

  # This secret must be created manually or by the test-cloud.ps1 script before running Terraform
  # For production environments, it's recommended to let RDS manage its own password automatically
  # by removing the manage_master_user_password = false and password parameters
}

data "aws_secretsmanager_secret_version" "rds_password" {
  secret_id = data.aws_secretsmanager_secret.rds_password.id
}

# Local value to safely extract password from secret
locals {
  # Try to parse as JSON first, fallback to plain text
  secret_data = try(
    jsondecode(data.aws_secretsmanager_secret_version.rds_password.secret_string),
    { "DB_PASSWORD" = data.aws_secretsmanager_secret_version.rds_password.secret_string }
  )
  db_password = local.secret_data["DB_PASSWORD"]
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.5.0"

  identifier     = "tii-assessment-db"
  engine         = "postgres"
  engine_version = "16.8"
  # I'm using the smallest instance class to keep the cost low for the demo
  instance_class    = "db.t3.small"
  allocated_storage = 20
  family            = "postgres16"

  db_name  = var.db_name
  username = var.db_username

  # IMPORTANT: For production environments, it's highly recommended to let RDS manage its own password
  # by setting manage_master_user_password = true and removing the password parameter.
  # This enables automatic password rotation and better security practices.
  # 
  # For this demo, I'm using a pre-created secret to simplify the setup.
  # The secret "tii-assessment/db-password" must be created by the test-cloud.ps1 script
  # or manually in AWS Secrets Manager before running this Terraform configuration.
  manage_master_user_password = false
  password                    = local.db_password

  port = 5432

  # RDS is in the same VPC as the EKS cluster, so we can use the default security group
  multi_az               = true
  vpc_security_group_ids = [aws_security_group.rds.id]
  # Using groups helps to balance the connection from EKS to RDS in multiple AZs
  db_subnet_group_name = module.vpc.database_subnet_group

  # Using a custom parameter group
  parameter_group_name = aws_db_parameter_group.postgres.name

  # optional parameters, to increase security
  storage_encrypted       = true
  backup_retention_period = 7
  publicly_accessible     = false
  skip_final_snapshot     = true

  tags = {
    Project = "TII Assessment - Architecting IoT Solutions"
  }
}
