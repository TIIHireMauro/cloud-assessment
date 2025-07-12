# ECR - Documentation: https://registry.terraform.io/modules/terraform-aws-modules/ecr/aws/latest
# I'm using modules to keep the code clean and easy to understand

# Adicionar data source para pegar o account_id

data "aws_caller_identity" "current" {}

# Adicionar policy document para liberar acesso total ao ECR para todos os usuários da conta

data "aws_iam_policy_document" "ecr_repository" {
  statement {
    sid    = "AllowAllActionsForAccount"
    effect = "Allow"
    actions = ["ecr:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

# Adicionar repository_policy_text ao módulo ECR
module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "2.0.0"

  repository_name = "backend"
  repository_force_delete = true
  repository_image_tag_mutability = "MUTABLE"
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 30 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only 5 tagged images per tag (allows mutable tags)"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["latest", "v"]
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
  tags = {
    Name        = "backend-repository"
    Environment = "production"
    Project     = "tii-assessment"
  }
  repository_policy = data.aws_iam_policy_document.ecr_repository.json
}

resource "aws_ecr_repository" "simulator" {
  name = "simulator"
}