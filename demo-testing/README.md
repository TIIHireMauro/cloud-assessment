# ☁️ Cloud Test - TII IoT Assessment

This document describes how to set up and test the cloud environment of the IoT Data Collector system on AWS.

## 📋 Available Scripts

### Local Scripts (Kind)
- **`test-local.ps1`** - PowerShell script for local testing with Kind
- **`cleanup-local.ps1`** - PowerShell script for local environment cleanup

### Cloud Scripts (AWS)
- **`test-cloud.ps1`** - PowerShell script for AWS deployment and testing
- **`cleanup-cloud.ps1`** - PowerShell script for AWS environment cleanup
- **`fix-ecr-permissions.ps1`** - PowerShell script for diagnosing and fixing ECR permissions issues



## 📋 Prerequisites

Before running the cloud test, make sure you have installed and configured:

### 1. Required Tools
- **AWS CLI** - [Installation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Terraform** - [Installation](https://developer.hashicorp.com/terraform/downloads)
- **kubectl** - [Installation](https://kubernetes.io/docs/tasks/tools/)
- **Helm** - [Installation](https://helm.sh/docs/intro/install/)
- **Docker** - [Installation](https://docs.docker.com/get-docker/)
- **KinD** - [Installation](https://kind.sigs.k8s.io/docs/user/quick-start/)

### 2. AWS Configuration
```bash
# Configure AWS credentials
# You'll need an IAM user with priviledges below an Access Key.
# Also need to define the region. Please choose a region that has 3 Az, to match the requirements for this assessment.
aws configure

# Verify it's working
aws sts get-caller-identity
```

### 3. Required AWS Permissions
Your AWS account must have the following permissions:
- **EC2** - To create EKS instances
- **EKS** - To manage Kubernetes clusters
- **RDS** - To create PostgreSQL database
- **ECR** - To store Docker images
- **IAM** - To create roles and policies
- **IoT Core** - To manage IoT devices
- **Lambda** - To run simulators
- **VPC** - To create network and subnets
- **Secrets Manager** - To manage secrets

## 🚀 Running the Cloud Test

### Step 1: Run the Main Script

#### Windows (PowerShell)
```powershell
# Navigate to project directory
cd cloud-assessment

# Run cloud test script
.\Test\test-cloud.ps1
```

#### Linux/macOS (Bash)
```bash
# Navigate to project directory
cd cloud-assessment

# Run cloud test script
./demo-testing/test-cloud.sh
```

### Step 2: What the Script Does

The `test-cloud.ps1` script automatically executes:

1. **🏗️ AWS Infrastructure Deployment**
   - Creates VPC with public and private subnets
   - Deploys EKS cluster
   - Creates RDS PostgreSQL database
   - Configures AWS IoT Core
   - Creates Lambda function for simulation
   - Configures IAM roles and policies

2. **📦 Image Preparation**
   - Builds backend Docker image
   - Pushes image to ECR (Elastic Container Registry)
   - Configures ECR login

3. **📊 Application Deployment**
   - Installs External Secrets Operator
   - Deploys application via Helm
   - Configures Prometheus and Grafana

4. **🧪 Automated Tests**
   - Service connectivity verification
   - Backend metrics testing
   - Prometheus and Grafana validation
   - Lambda simulator testing

## 🔍 Verifying the Environment

### Pod Status
```bash
kubectl get pods
```

### Backend Logs
```bash
kubectl logs -l app=backend
```

### Accessing Services

#### Via Port-Forward (Recommended for Testing)
```bash
# Backend API
kubectl port-forward svc/backend 3000:3000

# Prometheus
kubectl port-forward svc/prometheus 9090:9090

# Grafana
kubectl port-forward svc/grafana 3001:3000
```

#### Access URLs
- **Backend API**: http://localhost:3000
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3001

### Checking Metrics
```bash
# Check backend metrics
curl http://localhost:3000/metrics

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets
```

## 📊 Monitoring

### Grafana Dashboards
Grafana comes pre-configured with dashboards for:
- **MQTT Message Rate** - MQTT message rate
- **Database Writes** - Database writes
- **System Metrics** - System metrics

### Prometheus Targets
Prometheus is configured to collect metrics from:
- Backend API (port 3000)
- Kubernetes system
- Custom application metrics

## 🔧 Troubleshooting

### Common Issues

#### 1. Terraform Deployment Failure
```bash
# Check Terraform logs
cd infrastructure/terraform
terraform plan
terraform apply -auto-approve
```

#### 2. Pods Not Ready
```bash
# Check pod events
kubectl describe pods

# Check pod logs
kubectl logs <pod-name>
```

#### 3. Connectivity Issues
```bash
# Check if services are running
kubectl get svc

# Test internal connectivity
kubectl exec -it <pod-name> -- curl http://backend:3000/metrics
```

#### 4. ECR Issues

**Timeout no login ECR:**
Se você encontrar timeout no comando `aws ecr get-login-password`, execute o script de diagnóstico:

```powershell
# Execute o script de diagnóstico ECR
.\demo-testing\fix-ecr-permissions.ps1
```

**Soluções manuais:**

1. **Verificar permissões IAM:**
```bash
# Verificar se o usuário tem permissões ECR
aws iam get-user
aws iam list-attached-user-policies --user-name <seu-usuario>
```

2. **Adicionar permissões ECR manualmente:**
```bash
# Criar política ECR
aws iam create-policy --policy-name ECRFullAccess --policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ],
      "Resource": "*"
    }
  ]
}'

# Anexar política ao usuário
aws iam attach-user-policy --user-name <seu-usuario> --policy-arn arn:aws:iam::<account-id>:policy/ECRFullAccess
```

3. **Re-login to ECR com timeout aumentado:**
```bash
# Definir timeout maior
export AWS_CLI_TIMEOUT=60
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-west-1.amazonaws.com
```

## 🗑️ Environment Cleanup

### Complete Cleanup

#### Windows (PowerShell)
```powershell
# Run cleanup script
.\Test\cleanup-cloud.ps1
```

#### Linux/macOS (Bash)
```bash
# Run cleanup script
./demo-testing/cleanup-cloud.sh
```

### Manual Cleanup (if needed)
```bash
# Remove Helm application
helm uninstall tii-assessment-cloud

# Destroy Terraform infrastructure
cd infrastructure/terraform
terraform destroy -auto-approve
cd ../..

# Remove ECR images
aws ecr batch-delete-image --repository-name backend --image-ids imageTag=latest --region eu-west-1
```

## 💰 AWS Costs

### Cost Estimate (approximate)
https://calculator.aws/#/estimate?id=b2af02a699d0e78d8e3f89714b4581ee14d6a5b0

| Service            | Estimated Cost (USD/month) | Notes                                         |
|--------------------|---------------------------|-----------------------------------------------|
| EKS                | 70-100                    | Small cluster (2-3 t3.medium nodes)           |
| RDS PostgreSQL     | 30-50                     | db.t3.micro instance, 20GB SSD                |
| ECR                | 5-10                      | Docker image storage                          |
| AWS IoT Core       | 5-15                      | Low message volume                            |
| Lambda             | 1-5                       | Only for device simulation functions          |
| NAT Gateway        | 45                        | Fixed monthly cost per gateway                |
| Others (VPC, etc.) | 5-30                      | IPs, data transfer, logs                      |
| **Total**          | **150-225**               |                                               |

### Tips to Reduce Costs
1. Run tests only when necessary
2. Use cleanup script after tests
3. Configure AWS billing alerts
4. Use spot instances for EKS (if possible)
5. Make commitments/reservations for 1-3 years (RDS)

## 📝 Important Notes

### Security
- Database credentials are managed by AWS Secrets Manager
- External Secrets Operator automatically syncs secrets
- All communications are encrypted (TLS/SSL)

### Scalability
- EKS cluster supports auto-scaling
- RDS can be scaled vertically
- System is prepared for high availability

### Observability
- Metrics are exposed via `/metrics` endpoint
- Prometheus automatically collects metrics
- Pre-configured Grafana dashboards
- Centralized logs via Kubernetes

## 🆘 Support

If you encounter issues:
1. Check pod logs
2. Consult AWS documentation
3. Check IAM permissions
4. Run cleanup script and try again

---

# 🏠 Local Test - TII IoT Assessment

This document describes how to set up and test the local environment of the IoT Data Collector system using Kind (Kubernetes in Docker).

## 📋 Prerequisites

Before running the local test, make sure you have installed and configured:

### 1. Required Tools
- **Docker** - [Installation](https://docs.docker.com/get-docker/)
- **Kind** - [Installation](https://kind.sigs.k8s.io/docs/user/quick-start/)
- **kubectl** - [Installation](https://kubernetes.io/docs/tasks/tools/)
- **Helm** - [Installation](https://helm.sh/docs/intro/install/)

## 🚀 Running the Local Test

### Step 1: Run the Main Script

#### Windows (PowerShell)
```powershell
# Navigate to project directory
cd cloud-assessment

# Run local test script
.\demo-testing\test-local.ps1
```

#### Linux/macOS (Bash)
```bash
# Navigate to project directory
cd cloud-assessment

# Run local test script
./demo-testing/test-local.sh
```

### Step 2: What the Script Does

The script automatically executes:

1. **🐳 Environment Preparation**
   - Verifies Docker, kubectl, kind and helm
   - Creates Kind cluster with port mappings
   - Configures kubectl context

2. **📦 Image Building**
   - Builds backend Docker image
   - Builds simulator Docker image
   - Loads images into Kind cluster

3. **🗄️ Database Configuration**
   - Creates secret for PostgreSQL password
   - Deploys PostgreSQL via Helm

4. **📊 Application Deployment**
   - Complete deployment via Helm chart
   - Prometheus and Grafana configuration
   - IoT simulator deployment

5. **🧪 Automated Tests**
   - Service connectivity verification
   - Backend metrics testing
   - Prometheus and Grafana validation
   - IoT data verification

## 🔍 Verifying the Local Environment

### Pod Status
```bash
kubectl get pods
```

### Accessing Services

Services are accessible directly via localhost:
- **Backend API**: http://localhost:3000
- **Grafana**: http://localhost:3001 (admin/admin)
- **Prometheus**: http://localhost:9090
- **PostgreSQL**: localhost:5432
- **MQTT Broker**: localhost:1883

### Checking Metrics
```bash
# Check backend metrics
curl http://localhost:3000/metrics

# Check API data
curl http://localhost:3000/api/data
```

## 🗑️ Local Environment Cleanup

### Complete Cleanup

#### Windows (PowerShell)
```powershell
# Run cleanup script
.\demo-testing\cleanup-local.ps1
```

#### Linux/macOS (Bash)
```bash
# Run cleanup script
./demo-testing/cleanup-local.sh
```

### Manual Cleanup (if needed)
```bash
# Remove Helm application
helm uninstall tii-assessment

# Stop Kind cluster
kind delete cluster --name iot-local

# Remove Docker images
docker rmi backend:latest simulator:latest
```

## 🔧 Local Troubleshooting

### Common Issues

#### 1. Ports Already in Use
```bash
# Check ports in use
netstat -tulpn | grep :3000
netstat -tulpn | grep :3001
netstat -tulpn | grep :9090

# Stop processes using the ports
```

#### 2. Kind Cluster Won't Start
```bash
# Check if Docker is running
docker info

# Recreate cluster
kind delete cluster --name iot-local
kind create cluster --name iot-local
```

#### 3. Images Won't Load
```bash
# Check if images were built
docker images | grep backend
docker images | grep simulator

# Reload images
kind load docker-image backend:latest --name iot-local
kind load docker-image simulator:latest --name iot-local
```

## 📝 Local Environment Advantages

### Development
- **Fast**: Setup in minutes
- **Isolated**: Doesn't interfere with other environments
- **Cheap**: No infrastructure costs
- **Flexible**: Easy to modify and test

### Testing
- **Reproducible**: Same environment always
- **Portable**: Works on any machine
- **Secure**: Local data, no external exposure 