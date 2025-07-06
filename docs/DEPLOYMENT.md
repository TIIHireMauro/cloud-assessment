# 🚀 Deployment Guide

## 📋 Overview

This guide provides step-by-step instructions for deploying the IoT Data Collector System in both local and cloud environments.

## 🏠 Local Deployment

### Prerequisites

1. **Docker Desktop**
   ```bash
   # Install Docker Desktop
   # Windows: https://docs.docker.com/desktop/install/windows/
   # macOS: https://docs.docker.com/desktop/install/mac/
   # Linux: https://docs.docker.com/desktop/install/linux/
   ```

2. **kubectl**
   ```bash
   # Windows (PowerShell)
   winget install -e --id Kubernetes.kubectl
   
   # macOS
   brew install kubectl
   
   # Linux
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
   ```

3. **Helm**
   ```bash
   # Windows (PowerShell)
   winget install -e --id Helm.Helm
   
   # macOS
   brew install helm
   
   # Linux
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
   ```

4. **Kind (Kubernetes in Docker)**
   ```bash
   # Windows (PowerShell)
   winget install -e --id Kind.Kind
   
   # macOS
   brew install kind
   
   # Linux
   curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
   chmod +x ./kind
   sudo mv ./kind /usr/local/bin/kind
   ```

### Step 1: Create Local Kubernetes Cluster

```bash
# Create a new Kind cluster
kind create cluster --name iot-cluster

# Verify cluster is running
kubectl cluster-info
kubectl get nodes
```

### Step 2: Deploy the Application

```bash
# Navigate to project root
cd cloud-assessment

# Deploy using Helm
helm install iot-system ./chart \
  --values chart/values-local.yaml \
  --namespace iot-system \
  --create-namespace \
  --wait \
  --timeout=10m
```

### Step 3: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n iot-system

# Check services
kubectl get services -n iot-system

# Port forward to access services
kubectl port-forward -n iot-system svc/backend 3000:3000 &
kubectl port-forward -n iot-system svc/grafana 3001:3000 &
kubectl port-forward -n iot-system svc/prometheus 9090:9090 &
```

### Step 4: Access the Application

- **Backend API**: http://localhost:3000
- **Grafana**: http://localhost:3001 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Metrics Endpoint**: http://localhost:3000/metrics

### Step 5: Test the System

```bash
# Check if simulator is sending data
kubectl logs -n iot-system deployment/simulator -f

# Check backend logs
kubectl logs -n iot-system deployment/backend -f

# Test API endpoint
curl http://localhost:3000/api/data
```

## ☁️ Cloud Deployment (AWS)

### Prerequisites

1. **AWS CLI**
   ```bash
   # Windows
   winget install -e --id Amazon.AWSCLI
   
   # macOS
   brew install awscli
   
   # Linux
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   ```

2. **AWS Configuration**
   ```bash
   # Configure AWS credentials
   aws configure
   
   # Verify configuration
   aws sts get-caller-identity
   ```

3. **Terraform**
   ```bash
   # Windows
   winget install -e --id HashiCorp.Terraform
   
   # macOS
   brew install terraform
   
   # Linux
   curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
   sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
   sudo apt-get update && sudo apt-get install terraform
   ```

### Step 1: Deploy Infrastructure

```bash
# Navigate to Terraform directory
cd infrastructure/terraform

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var="environment=production"

# Apply the infrastructure
terraform apply -var="environment=production" -auto-approve
```

### Step 2: Configure kubectl for EKS

```bash
# Update kubeconfig for the new cluster
aws eks update-kubeconfig --region eu-west-1 --name iot-cluster

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### Step 3: Deploy Application

```bash
# Navigate back to project root
cd ../../

# Deploy using Helm
helm install iot-system ./chart \
  --values chart/values-cloud.yaml \
  --namespace iot-system \
  --create-namespace \
  --wait \
  --timeout=10m
```

### Step 4: Configure External Secrets

```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace

# Create secret store
kubectl apply -f chart/templates/secret-store.yaml

# Create external secret
kubectl apply -f chart/templates/external-secret.yaml
```

### Step 5: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n iot-system

# Check services
kubectl get services -n iot-system

# Get Load Balancer URL
kubectl get service backend -n iot-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Step 6: Access the Application

- **Backend API**: Use the Load Balancer URL
- **Grafana**: Port forward or use Load Balancer
- **Prometheus**: Port forward for internal access

## 🔧 Configuration

### Environment Variables

#### Backend Configuration
```yaml
# chart/values.yaml
backend:
  env:
    MQTT_BROKER_URL: "mqtt://mosquitto:1883"
    MQTT_TOPIC: "iot/data"
    DB_HOST: "postgres"
    DB_PORT: "5432"
    DB_USER: "tiiassessment"
    DB_NAME: "tiiassessment"
    DB_PASSWORD_SECRET_NAME: "db-secret"
    PORT: "3000"
```

#### Cloud Configuration
```yaml
# chart/values-cloud.yaml
backend:
  env:
    MQTT_BROKER_URL: "mqtt://aws-iot-core-endpoint"
    MQTT_TOPIC: "iot/data"
    DB_HOST: "rds-endpoint"
    DB_PORT: "5432"
    DB_USER: "tiiassessment"
    DB_NAME: "tiiassessment"
    DB_PASSWORD_SECRET_NAME: "db-secret"
    PORT: "3000"
```

### Secrets Management

#### Local Environment
```bash
# Create database secret
kubectl create secret generic db-secret \
  --from-literal=DB_PASSWORD=your_password \
  -n iot-system
```

#### Cloud Environment
```bash
# Store secret in AWS Secrets Manager
aws secretsmanager create-secret \
  --name "iot-system/db-password" \
  --description "Database password for IoT system" \
  --secret-string '{"DB_PASSWORD":"your_secure_password"}'
```

## 📊 Monitoring Setup

### Prometheus Configuration

```yaml
# chart/templates/prometheus-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'backend'
        static_configs:
          - targets: ['backend:3000']
        metrics_path: '/metrics'
```

### Grafana Dashboards

```bash
# Import dashboard
kubectl apply -f chart/templates/grafana-dashboards.yaml

# Access Grafana
kubectl port-forward -n iot-system svc/grafana 3001:3000
```

## 🧪 Testing

### Automated Testing

```bash
# Run local tests
./demo-testing/test-local.ps1

# Run cloud tests
./demo-testing/test-cloud.ps1
```

### Manual Testing

```bash
# Test MQTT connection
mosquitto_pub -h localhost -t "iot/data" -m '{"device_id":"test","temperature":25.5}'

# Test API endpoint
curl -X GET http://localhost:3000/api/data

# Test metrics endpoint
curl http://localhost:3000/metrics
```

## 🗑️ Cleanup

### Local Cleanup

```bash
# Delete Helm release
helm uninstall iot-system -n iot-system

# Delete namespace
kubectl delete namespace iot-system

# Delete Kind cluster
kind delete cluster --name iot-cluster
```

### Cloud Cleanup

```bash
# Delete Helm release
helm uninstall iot-system -n iot-system

# Delete namespace
kubectl delete namespace iot-system

# Destroy Terraform infrastructure
cd infrastructure/terraform
terraform destroy -var="environment=production" -auto-approve
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Pods Not Starting
```bash
# Check pod status
kubectl get pods -n iot-system

# Check pod logs
kubectl logs -n iot-system <pod-name>

# Check pod events
kubectl describe pod -n iot-system <pod-name>
```

#### 2. Database Connection Issues
```bash
# Check database pod
kubectl logs -n iot-system deployment/postgres

# Check backend logs
kubectl logs -n iot-system deployment/backend

# Test database connection
kubectl exec -n iot-system deployment/postgres -- psql -U tiiassessment -d tiiassessment
```

#### 3. MQTT Connection Issues
```bash
# Check MQTT broker
kubectl logs -n iot-system deployment/mosquitto

# Check simulator logs
kubectl logs -n iot-system deployment/simulator

# Test MQTT connection
kubectl port-forward -n iot-system svc/mosquitto 1883:1883
mosquitto_pub -h localhost -t "test" -m "hello"
```

#### 4. Monitoring Issues
```bash
# Check Prometheus
kubectl logs -n iot-system deployment/prometheus

# Check Grafana
kubectl logs -n iot-system deployment/grafana

# Verify metrics endpoint
curl http://localhost:3000/metrics
```

### Performance Tuning

#### Resource Limits
```yaml
# chart/templates/backend-deployment.yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

#### Scaling
```bash
# Scale backend replicas
kubectl scale deployment backend --replicas=3 -n iot-system

# Check scaling status
kubectl get pods -n iot-system
```

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/) 