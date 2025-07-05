# This file is temporary and used to create the secrets on AWS Secrets Manager
# in the future, I will use CICD to create the secrets

# Documentation: https://registry.terraform.io/modules/terraform-aws-modules/secrets-manager/aws/latest

module "db_secret" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "1.10.0"

  name        = "db-password"
  description = "Database password for backend"
  secret_string = jsonencode({
    DB_PASSWORD = var.db_password
  })
}
