#!/bin/bash

# Local Test Script for TII IoT Assessment
# This script sets up and tests the IoT Data Collector system locally using Kind

set -e  # Exit on any error

echo "🏠 Starting Local Test for TII IoT Assessment..."

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

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install it first."
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi

# Check Kind
if ! command -v kind &> /dev/null; then
    print_error "Kind is not installed. Please install it first."
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

print_status "All prerequisites are installed and running."

# Check if Kind cluster already exists
CLUSTER_NAME="iot-local"
if kind get clusters | grep -q "$CLUSTER_NAME"; then
    print_warning "Kind cluster '$CLUSTER_NAME' already exists."
    read -p "Do you want to delete it and create a new one? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deleting existing Kind cluster..."
        kind delete cluster --name "$CLUSTER_NAME"
    else
        print_status "Using existing Kind cluster."
    fi
fi

# Create Kind cluster if it doesn't exist
if ! kind get clusters | grep -q "$CLUSTER_NAME"; then
    print_status "Creating Kind cluster..."
    kind create cluster --name "$CLUSTER_NAME" --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 3000
    hostPort: 3000
  - containerPort: 3001
    hostPort: 3001
  - containerPort: 9090
    hostPort: 9090
  - containerPort: 5432
    hostPort: 5432
  - containerPort: 1883
    hostPort: 1883
EOF
    print_status "Kind cluster created successfully."
fi

# Set kubectl context
print_status "Setting kubectl context..."
kubectl cluster-info --context "kind-$CLUSTER_NAME"

# Wait for cluster to be ready
print_status "Waiting for cluster to be ready..."
kubectl wait --for=condition=ready nodes --all --timeout=300s

# Build Docker images
print_status "Building Docker images..."

# Build backend image
print_status "Building backend image..."
cd backend
docker build -t backend:latest .
cd ..

# Build simulator image
print_status "Building simulator image..."
cd simulator
docker build -t simulator:latest .
cd ..

# Load images into Kind cluster
print_status "Loading images into Kind cluster..."
kind load docker-image backend:latest --name "$CLUSTER_NAME"
kind load docker-image simulator:latest --name "$CLUSTER_NAME"

print_status "Docker images loaded into Kind cluster."

# Create namespace
print_status "Creating namespace..."
kubectl create namespace tii-assessment --dry-run=client -o yaml | kubectl apply -f -

# Create database password secret
print_status "Creating database password secret..."
DB_PASSWORD=$(openssl rand -base64 32)
kubectl create secret generic db-credentials \
    --from-literal=DB_PASSWORD="$DB_PASSWORD" \
    --namespace tii-assessment \
    --dry-run=client -o yaml | kubectl apply -f -

print_status "Database password secret created."

# Deploy application
print_status "Deploying application..."
helm install tii-assessment chart/ \
    --values chart/values-local.yaml \
    --namespace tii-assessment \
    --wait

print_status "Application deployed successfully."

# Wait for pods to be ready
print_status "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pods --all --namespace tii-assessment --timeout=300s

# Test the deployment
print_status "Testing the deployment..."

# Test backend connectivity
print_status "Testing backend connectivity..."
sleep 10  # Give backend time to start

if curl -f http://localhost:3000/metrics &> /dev/null; then
    print_status "Backend metrics endpoint is working."
else
    print_error "Backend metrics endpoint is not working."
    exit 1
fi

# Test Prometheus
print_status "Testing Prometheus..."
sleep 5

if curl -f http://localhost:9090/api/v1/targets &> /dev/null; then
    print_status "Prometheus is working."
else
    print_error "Prometheus is not working."
    exit 1
fi

# Test Grafana
print_status "Testing Grafana..."
sleep 5

if curl -f http://localhost:3001/api/health &> /dev/null; then
    print_status "Grafana is working."
else
    print_error "Grafana is not working."
    exit 1
fi

# Test API data endpoint
print_status "Testing API data endpoint..."
if curl -f http://localhost:3000/api/data &> /dev/null; then
    print_status "API data endpoint is working."
else
    print_error "API data endpoint is not working."
    exit 1
fi

print_status "✅ All tests passed successfully!"

# Display access information
echo ""
echo "🎉 Local deployment completed successfully!"
echo ""
echo "📊 Access Information:"
echo "  Backend API: http://localhost:3000"
echo "  Prometheus:  http://localhost:9090"
echo "  Grafana:     http://localhost:3001 (admin/admin)"
echo "  PostgreSQL:  localhost:5432"
echo "  MQTT Broker: localhost:1883"
echo ""
echo "🔗 API Endpoints:"
echo "  Metrics:     http://localhost:3000/metrics"
echo "  Data:        http://localhost:3000/api/data"
echo ""
echo "🗑️  To cleanup, run: ./demo-testing/cleanup-local.sh"
echo "" 