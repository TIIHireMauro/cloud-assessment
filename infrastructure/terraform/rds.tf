# RDS - Documentation: https://registry.terraform.io/modules/terraform-aws-modules/rds/aws/latest
# I'm using modules to keep the code clean and easy to understand
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.5.0"

  identifier = "tii-assessment-db"
  engine     = "postgres"
  engine_version = "16.4"
  instance_class = "db.t3.small"
  allocated_storage = 20
  family = "postgres16"

  db_name  = var.db_name
  username = var.db_username
  
  # This is a very important point. 
  # With the next parameter, RDS will:
  # 1 - Create a new master user password
  # 2 - Store the password in the secrets manager
  # 3 - Rotate the password every 7 days
  # Also, the ARN of the secret will be exposed on outputs and used by Helm to configure the backend service account,
  # protecting the password for the entire lifetime of the database, which is a good practice
  manage_master_user_password = true

  port = 5432

  # RDS is in the same VPC as the EKS cluster, so we can use the default security group
  # Using groups helps to balance the connection from EKS to RDS in multiple AZs
  multi_az                = true
  vpc_security_group_ids = [module.vpc.default_security_group_id]
  db_subnet_group_name   = module.vpc.database_subnet_group

  # optional parameters, to increase security
  storage_encrypted       = true
  backup_retention_period = 7
  publicly_accessible     = false
  skip_final_snapshot     = true

  tags = {
    Project = "TII Assessment - Architecting IoT Solutions"
  }
}
