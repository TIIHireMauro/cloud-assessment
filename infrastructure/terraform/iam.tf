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
  name = "backend-secrets-policy"
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

# Policy para IoT Core
resource "aws_iam_policy" "backend_iot_policy" {
  name = "backend-iot-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "iot:Connect",
          "iot:Publish",
          "iot:Subscribe",
          "iot:Receive"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_iot_attach" {
  role       = module.backend_irsa.iam_role_name
  policy_arn = aws_iam_policy.backend_iot_policy.arn
}

# Policy for SQS
resource "aws_iam_policy" "backend_sqs_policy" {
  name = "backend-sqs-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_sqs_attach" {
  role       = module.backend_irsa.iam_role_name
  policy_arn = aws_iam_policy.backend_sqs_policy.arn
}

# Policy para push ECR
resource "aws_iam_policy" "ecr_push_policy" {
  name = "ecr-push-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ],
        Resource = "*"
      }
    ]
  })
}

data "aws_iam_user" "local_user" {
  user_name = "vendorview"
}

resource "aws_iam_user_policy_attachment" "local_user_ecr_attach" {
  user       = data.aws_iam_user.local_user.user_name
  policy_arn = aws_iam_policy.ecr_push_policy.arn
}

# IRSA para o simulador
module "simulator_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.36.0"

  role_name = "eks-simulator-sa-role"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:simulator-sa"]
    }
  }
}

# Policy para IoT Core (simulador)
resource "aws_iam_policy" "simulator_iot_policy" {
  name = "simulator-iot-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "iot:Connect",
          "iot:Publish",
          "iot:Subscribe",
          "iot:Receive"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "simulator_iot_attach" {
  role       = module.simulator_irsa.iam_role_name
  policy_arn = aws_iam_policy.simulator_iot_policy.arn
}