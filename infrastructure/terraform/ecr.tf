# ECR - Documentation: https://registry.terraform.io/modules/terraform-aws-modules/ecr/aws/latest
# I'm using modules to keep the code clean and easy to understand
module "ecr" {
  source = "terraform-aws-modules/ecr/aws"
  version = "2.0.0"

  # Backend repository
  repository_name = "backend"
  
  # Allow mutable tags (same tag can be overwritten)
  repository_force_delete = true
  repository_image_tag_mutability = "MUTABLE"

  # Lifecycle policy to expire untagged images older than 30 days (for demo purposes)
  # And allow mutable tags (same tag can be overwritten)
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
}