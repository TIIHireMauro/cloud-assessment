# Terraform Infrastructure for TII IoT Assessment

This directory contains the Terraform configuration for the AWS infrastructure used in the TII IoT Assessment.

## Architecture Overview

The infrastructure includes:
- **VPC** with public and private subnets across multiple AZs
- **EKS Cluster** for running the application
- **RDS PostgreSQL** database for data storage
- **ECR Repositories** for Docker images
- **IoT Core** for MQTT messaging
- **Lambda Function** for IoT data simulation
- **IAM Roles** and policies for service accounts

## Database Configuration

### Demo Configuration (Current)

The current configuration uses a pre-created secret in AWS Secrets Manager for the database password:

1. **Secret Name**: `tii-assessment/db-password`
2. **Created by**: `test-cloud.ps1` script or manually
3. **Purpose**: Simplifies demo setup

**Important**: The secret must exist before running Terraform. The `test-cloud.ps1` script creates this secret automatically.

### Production Configuration (Recommended)

For production environments, it's **highly recommended** to let RDS manage its own password:

1. **Automatic Password Management**: RDS creates and rotates passwords automatically
2. **Better Security**: No hardcoded passwords in code
3. **Compliance**: Meets security best practices

See `rds-production.tf.example` for the recommended production configuration.

## Prerequisites

1. **AWS CLI** configured with appropriate permissions
2. **Terraform** installed (version >= 1.0)
3. **Secret created** in AWS Secrets Manager (for demo setup)

## Usage

### Demo Setup

```bash
# Run the test-cloud.ps1 script which will:
# 1. Create the secret in AWS Secrets Manager
# 2. Deploy infrastructure with Terraform
# 3. Build and push Docker images
# 4. Deploy the application

./demo-testing/test-cloud.ps1
```

### Manual Setup

```bash
# 1. Create the secret manually (if not using test-cloud.ps1)
aws secretsmanager create-secret \
  --name "tii-assessment/db-password" \
  --description "Database password for TII Assessment" \
  --secret-string '{"DB_PASSWORD":"your-secure-password"}'

# 2. Initialize Terraform
terraform init

# 3. Plan the deployment
terraform plan

# 4. Apply the configuration
terraform apply
```

### Production Setup

1. Copy `rds-production.tf.example` to `rds-production.tf`
2. Update the configuration as needed
3. Remove the demo secret references
4. Update IAM policies to access RDS-generated secrets

## Security Best Practices

### Demo Environment
- ✅ Uses AWS Secrets Manager (not hardcoded passwords)
- ✅ Encrypted storage
- ✅ Private subnets
- ✅ Security groups with minimal access

### Production Environment
- ✅ RDS-managed passwords with automatic rotation
- ✅ Deletion protection enabled
- ✅ Automated backups
- ✅ Maintenance windows configured
- ✅ Enhanced monitoring
- ✅ Audit logging

## Cleanup

Use the cleanup script to remove all resources:

```bash
./demo-testing/cleanup-cloud.ps1
```

This will:
1. Remove Helm deployments
2. Delete ECR images
3. Remove AWS Secrets Manager secrets
4. Destroy all Terraform resources

## Important Notes

- **Demo Secret**: The secret `tii-assessment/db-password` is created for demo purposes only
- **Production**: Use RDS-managed passwords for production environments
- **Costs**: This infrastructure will incur AWS charges
- **Region**: All resources are created in the selected AWS region
- **Cleanup**: Always run cleanup to avoid unnecessary charges

## Troubleshooting

### Common Issues

1. **Secret not found**: Ensure the secret exists before running Terraform
2. **Permission denied**: Check AWS CLI configuration and IAM permissions
3. **VPC conflicts**: Ensure no conflicting VPC configurations exist
4. **EKS timeout**: Wait for cluster to be fully ready before deploying applications

### Useful Commands

```bash
# Check Terraform state
terraform show

# List all resources
terraform state list

# Check AWS resources
aws eks list-clusters
aws ecr describe-repositories
aws rds describe-db-instances
```
