#!/bin/bash

# Cloud Test Script for TII IoT Assessment
# This script deploys and tests the IoT Data Collector system on AWS

set -e  # Exit on any error

echo "🚀 Starting Cloud Test for TII IoT Assessment..."

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
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check Terraform
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install it first."
    exit 1
fi

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install it first."
    exit 1
fi

# Check Helm
if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed. Please install it first."
    exit 1
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install it first."
    exit 1
fi

print_status "All prerequisites are installed."

# Check AWS credentials
print_status "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials are not configured. Please run 'aws configure' first."
    exit 1
fi

print_status "AWS credentials are configured."

# Get AWS region
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    print_error "AWS region is not configured. Please run 'aws configure' first."
    exit 1
fi

print_status "Using AWS region: $AWS_REGION"

# Create database password secret
print_status "Creating database password secret..."
SECRET_NAME="tii-assessment/db-password"
DB_PASSWORD=$(openssl rand -base64 32)

# Check if secret already exists
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$AWS_REGION" &> /dev/null; then
    print_warning "Secret $SECRET_NAME already exists. Updating..."
    aws secretsmanager update-secret \
        --secret-id "$SECRET_NAME" \
        --secret-string "{\"DB_PASSWORD\":\"$DB_PASSWORD\"}" \
        --region "$AWS_REGION"
else
    aws secretsmanager create-secret \
        --name "$SECRET_NAME" \
        --description "Database password for TII Assessment" \
        --secret-string "{\"DB_PASSWORD\":\"$DB_PASSWORD\"}" \
        --region "$AWS_REGION"
fi

print_status "Database password secret created/updated."

# Deploy infrastructure with Terraform
print_status "Deploying infrastructure with Terraform..."
cd infrastructure/terraform

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -out=tfplan

# Apply deployment
terraform apply tfplan

# Get outputs
EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
ECR_REPOSITORY_URL=$(terraform output -raw ecr_repository_url)

print_status "Infrastructure deployed successfully."
print_status "EKS Cluster: $EKS_CLUSTER_NAME"
print_status "ECR Repository: $ECR_REPOSITORY_URL"

cd ../..

# Configure kubectl for EKS
print_status "Configuring kubectl for EKS cluster..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME"

# Wait for cluster to be ready
print_status "Waiting for EKS cluster to be ready..."
kubectl wait --for=condition=ready nodes --all --timeout=300s

# Build and push Docker image
print_status "Building and pushing Docker image..."
cd backend

# Build image
docker build -t backend:latest .

# Tag for ECR
docker tag backend:latest "$ECR_REPOSITORY_URL:latest"

# Login to ECR
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REPOSITORY_URL"

# Push to ECR
docker push "$ECR_REPOSITORY_URL:latest"

cd ..

print_status "Docker image pushed to ECR."

# Install External Secrets Operator
print_status "Installing External Secrets Operator..."
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets \
    --namespace external-secrets \
    --create-namespace \
    --wait

print_status "External Secrets Operator installed."

# Deploy application
print_status "Deploying application..."
helm install tii-assessment-cloud chart/ \
    --values chart/values-cloud.yaml \
    --set backend.image.repository="$ECR_REPOSITORY_URL" \
    --set backend.image.tag="latest" \
    --wait

print_status "Application deployed successfully."

# Wait for pods to be ready
print_status "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pods --all --timeout=300s

# Test the deployment
print_status "Testing the deployment..."

# Test backend connectivity
print_status "Testing backend connectivity..."
kubectl port-forward svc/backend 3000:3000 &
PORT_FORWARD_PID=$!

# Wait for port-forward to be ready
sleep 10

# Test metrics endpoint
if curl -f http://localhost:3000/metrics &> /dev/null; then
    print_status "Backend metrics endpoint is working."
else
    print_error "Backend metrics endpoint is not working."
    kill $PORT_FORWARD_PID 2>/dev/null || true
    exit 1
fi

# Test Prometheus
print_status "Testing Prometheus..."
kubectl port-forward svc/prometheus 9090:9090 &
PROMETHEUS_PID=$!

sleep 5

if curl -f http://localhost:9090/api/v1/targets &> /dev/null; then
    print_status "Prometheus is working."
else
    print_error "Prometheus is not working."
    kill $PROMETHEUS_PID 2>/dev/null || true
    exit 1
fi

# Test Grafana
print_status "Testing Grafana..."
kubectl port-forward svc/grafana 3001:3000 &
GRAFANA_PID=$!

sleep 5

if curl -f http://localhost:3001/api/health &> /dev/null; then
    print_status "Grafana is working."
else
    print_error "Grafana is not working."
    kill $GRAFANA_PID 2>/dev/null || true
    exit 1
fi

# Stop port-forwarding
kill $PORT_FORWARD_PID $PROMETHEUS_PID $GRAFANA_PID 2>/dev/null || true

print_status "✅ All tests passed successfully!"

# Display access information
echo ""
echo "🎉 Cloud deployment completed successfully!"
echo ""
echo "📊 Access Information:"
echo "  Backend API: kubectl port-forward svc/backend 3000:3000"
echo "  Prometheus:  kubectl port-forward svc/prometheus 9090:9090"
echo "  Grafana:     kubectl port-forward svc/grafana 3001:3000"
echo ""
echo "🔗 URLs (after port-forwarding):"
echo "  Backend API: http://localhost:3000"
echo "  Prometheus:  http://localhost:9090"
echo "  Grafana:     http://localhost:3001 (admin/admin)"
echo ""
echo "🗑️  To cleanup, run: ./demo-testing/cleanup-cloud.sh"
echo "" 