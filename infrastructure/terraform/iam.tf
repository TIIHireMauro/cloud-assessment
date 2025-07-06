# This file is used to create the IAM role for the backend service account
# and the policy to allow the backend service account to access the secrets manager (IRSA)

# Documentation: https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest

module "backend_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.36.0"

  role_name = "eks-backend-sa-role"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:backend-sa"]
    }
  }
}

# This is a policy to allow the backend service account to access the secrets manager
resource "aws_iam_policy" "backend_secrets_policy" {
  name   = "backend-secrets-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ],
        Resource = data.aws_secretsmanager_secret.rds_password.arn
      },
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_secrets_attach" {
  role       = module.backend_irsa.iam_role_name
  policy_arn = aws_iam_policy.backend_secrets_policy.arn
}