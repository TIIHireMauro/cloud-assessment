#!/bin/bash

# Local Cleanup Script for TII IoT Assessment
# This script removes all local resources created for the IoT Data Collector system

set -e  # Exit on any error

echo "🗑️ Starting Local Cleanup for TII IoT Assessment..."

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

# Check Kind
if ! command -v kind &> /dev/null; then
    print_error "Kind is not installed."
    exit 1
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed."
    exit 1
fi

print_status "All prerequisites are installed."

# Confirm cleanup
echo ""
print_warning "This will remove ALL local resources created for the TII IoT Assessment."
print_warning "This includes:"
echo "  - Kind cluster (iot-local)"
echo "  - Helm application (tii-assessment)"
echo "  - Docker images (backend:latest, simulator:latest)"
echo "  - Kubernetes secrets and namespaces"
echo ""
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Cleanup cancelled."
    exit 0
fi

# Remove Helm application
print_status "Removing Helm application..."
if helm list | grep -q "tii-assessment"; then
    helm uninstall tii-assessment
    print_status "Helm application removed."
else
    print_warning "Helm application not found."
fi

# Remove namespace
print_status "Removing namespace..."
if kubectl get namespace tii-assessment &> /dev/null; then
    kubectl delete namespace tii-assessment
    print_status "Namespace removed."
else
    print_warning "Namespace not found."
fi

# Delete Kind cluster
print_status "Deleting Kind cluster..."
CLUSTER_NAME="iot-local"
if kind get clusters | grep -q "$CLUSTER_NAME"; then
    kind delete cluster --name "$CLUSTER_NAME"
    print_status "Kind cluster deleted."
else
    print_warning "Kind cluster not found."
fi

# Remove Docker images
print_status "Removing Docker images..."
if docker images | grep -q "backend.*latest"; then
    docker rmi backend:latest
    print_status "Backend Docker image removed."
else
    print_warning "Backend Docker image not found."
fi

if docker images | grep -q "simulator.*latest"; then
    docker rmi simulator:latest
    print_status "Simulator Docker image removed."
else
    print_warning "Simulator Docker image not found."
fi

# Clean up any dangling images
print_status "Cleaning up dangling images..."
docker image prune -f

print_status "✅ Local cleanup completed successfully!"

echo ""
echo "🎉 All local resources have been removed."
echo ""
echo "📋 Summary of removed resources:"
echo "  ✅ Helm application (tii-assessment)"
echo "  ✅ Kubernetes namespace (tii-assessment)"
echo "  ✅ Kind cluster (iot-local)"
echo "  ✅ Docker images (backend:latest, simulator:latest)"
echo "  ✅ Dangling Docker images"
echo "" 