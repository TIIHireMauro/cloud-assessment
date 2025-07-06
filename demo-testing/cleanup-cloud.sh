#!/bin/bash

# Cloud Cleanup Script for TII IoT Assessment
# This script removes all AWS resources created for the IoT Data Collector system

set -e  # Exit on any error

echo "🗑️ Starting Cloud Cleanup for TII IoT Assessment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
print_status "Checking prerequisites..."

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed."
    exit 1
fi

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed."
    exit 1
fi

# Check Helm
if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed."
    exit 1
fi

# Check Terraform
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed."
    exit 1
fi

print_status "All prerequisites are installed."

# Check AWS credentials
print_status "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials are not configured."
    exit 1
fi

# Get AWS region
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    print_error "AWS region is not configured."
    exit 1
fi

print_status "Using AWS region: $AWS_REGION"

# Confirm cleanup
echo ""
print_warning "This will remove ALL AWS resources created for the TII IoT Assessment."
print_warning "This includes:"
echo "  - EKS Cluster"
echo "  - RDS Database"
echo "  - ECR Repositories"
echo "  - VPC and networking"
echo "  - IAM roles and policies"
echo "  - AWS Secrets Manager secrets"
echo "  - All associated costs"
echo ""
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Cleanup cancelled."
    exit 0
fi

# Remove Helm application
print_status "Removing Helm application..."
if helm list | grep -q "tii-assessment-cloud"; then
    helm uninstall tii-assessment-cloud
    print_status "Helm application removed."
else
    print_warning "Helm application not found."
fi

# Remove External Secrets Operator
print_status "Removing External Secrets Operator..."
if helm list -n external-secrets | grep -q "external-secrets"; then
    helm uninstall external-secrets -n external-secrets
    print_status "External Secrets Operator removed."
else
    print_warning "External Secrets Operator not found."
fi

# Get ECR repository URL from Terraform state
print_status "Getting ECR repository information..."
cd infrastructure/terraform

if [ -f "terraform.tfstate" ]; then
    ECR_REPOSITORY_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
    
    if [ -n "$ECR_REPOSITORY_URL" ]; then
        # Remove ECR images
        print_status "Removing ECR images..."
        aws ecr batch-delete-image \
            --repository-name backend \
            --image-ids imageTag=latest \
            --region "$AWS_REGION" 2>/dev/null || print_warning "Failed to remove ECR images."
        
        print_status "ECR images removed."
    fi
else
    print_warning "Terraform state not found."
fi

# Destroy Terraform infrastructure
print_status "Destroying Terraform infrastructure..."
if [ -f "terraform.tfstate" ]; then
    terraform destroy -auto-approve
    print_status "Terraform infrastructure destroyed."
else
    print_warning "Terraform state not found."
fi

cd ../..

# Remove AWS Secrets Manager secrets
print_status "Removing AWS Secrets Manager secrets..."
SECRET_NAME="tii-assessment/db-password"

if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$AWS_REGION" &> /dev/null; then
    aws secretsmanager delete-secret \
        --secret-id "$SECRET_NAME" \
        --force-delete-without-recovery \
        --region "$AWS_REGION"
    print_status "AWS Secrets Manager secret removed."
else
    print_warning "AWS Secrets Manager secret not found."
fi

# Clean up kubectl context
print_status "Cleaning up kubectl context..."
kubectl config unset current-context 2>/dev/null || true
kubectl config unset contexts.tii-assessment 2>/dev/null || true

print_status "✅ Cloud cleanup completed successfully!"

echo ""
echo "🎉 All AWS resources have been removed."
echo ""
echo "📋 Summary of removed resources:"
echo "  ✅ Helm application (tii-assessment-cloud)"
echo "  ✅ External Secrets Operator"
echo "  ✅ ECR images"
echo "  ✅ Terraform infrastructure (EKS, RDS, VPC, etc.)"
echo "  ✅ AWS Secrets Manager secrets"
echo "  ✅ kubectl context"
echo ""
echo "💰 AWS costs will stop accruing immediately."
echo "" 