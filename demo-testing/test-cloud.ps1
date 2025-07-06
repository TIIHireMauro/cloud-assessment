# This script is used to test/demo the cloud environment of the TII IoT Assessment
# It will:
# - create a ExternalSecret for the database password (AWS Secrets Manager)
# - create cloud environment with Terraform
# - deploy the Helm chart
# - run some tests (backend, prometheus, grafana)
#
# Requirements: (will be checked/installed if not present)
# - AWS CLI
# - EKS CLI
# - Helm
# - kubectl

# Logging functions
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor Blue
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

# Function to check if a command exists
function Test-Command {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

# Function to generate random password
function New-RandomPassword {
    param([int]$Length = 20)
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    $password = ""
    for ($i = 0; $i -lt $Length; $i++) {
        $password += $chars[(Get-Random -Maximum $chars.Length)]
    }
    return $password
}

# Function to validate AWS region
function Test-AWSRegion {
    param([string]$Region)
    
    $validRegions = @(
        "us-east-1", "us-east-2", "us-west-1", "us-west-2",
        "eu-west-1", "eu-west-2", "eu-west-3", "eu-central-1", "eu-north-1",
        "ap-southeast-1", "ap-southeast-2", "ap-northeast-1", "ap-northeast-2",
        "sa-east-1", "ca-central-1", "af-south-1", "me-south-1"
    )
    
    return $validRegions -contains $Region
}

# Function to select AWS region
function Select-AWSRegion {
    Write-Host ""
    Write-Log "🌍 AWS Region Selection"
    Write-Host "=====================" -ForegroundColor Gray
    
    $commonRegions = @(
        @{ Name = "US East (N. Virginia)"; Value = "us-east-1" },
        @{ Name = "US West (Oregon)"; Value = "us-west-2" },
        @{ Name = "Europe (Ireland)"; Value = "eu-west-1" },
        @{ Name = "Europe (Frankfurt)"; Value = "eu-central-1" },
        @{ Name = "Asia Pacific (Tokyo)"; Value = "ap-northeast-1" },
        @{ Name = "Asia Pacific (Singapore)"; Value = "ap-southeast-1" }
    )
    
    Write-Host "Common regions:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $commonRegions.Count; $i++) {
        Write-Host "  $($i + 1). $($commonRegions[$i].Name) ($($commonRegions[$i].Value))" -ForegroundColor White
    }
    Write-Host "  $($commonRegions.Count + 1). Other (custom region)" -ForegroundColor White
    
    do {
        $choice = Read-Host "`nSelect a region (1-$($commonRegions.Count + 1))"
        
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le ($commonRegions.Count + 1)) {
            if ([int]$choice -le $commonRegions.Count) {
                $selectedRegion = $commonRegions[[int]$choice - 1].Value
                Write-Success "Selected region: $selectedRegion"
                return $selectedRegion
            } else {
                # Custom region
                do {
                    $customRegion = Read-Host "Enter custom AWS region (e.g., us-east-1)"
                    if (Test-AWSRegion $customRegion) {
                        Write-Success "Selected custom region: $customRegion"
                        return $customRegion
                    } else {
                        Write-Error "Invalid region: $customRegion"
                        Write-Host "Please enter a valid AWS region code." -ForegroundColor Gray
                    }
                } while ($true)
            }
        } else {
            Write-Error "Invalid choice. Please select a number between 1 and $($commonRegions.Count + 1)"
        }
    } while ($true)
}

# Function to manage AWS Secrets Manager
function Initialize-AWSSecrets {
    param([string]$Region, [string]$Account_Id)
    
    $secretName = "tii-assessment/db-password"
    $secretArn = "arn:aws:secretsmanager:$Region`:$Account_Id`:$secretName"
    
    Write-Log "Checking AWS Secrets Manager..."
    
    # Check if secret already exists and force recreation for demo purposes
    try {
        $existingSecret = aws secretsmanager describe-secret --secret-id $secretName --region $Region 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Secret already exists, keeping it..."
            return $secretName
        }
    } catch {
        # Secret doesn't exist, create it
    }
    
    Write-Log "Creating new secret in AWS Secrets Manager..."
    $dbPassword = New-RandomPassword -Length 20
    
    $secretValue = @{
        DB_PASSWORD = $dbPassword
    } | ConvertTo-Json
    
    try {
        aws secretsmanager create-secret --name $secretName --description "Database password for TII Assessment" --secret-string $secretValue --region $Region
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Secret created successfully: $secretName"
            return $secretName
        } else {
            Write-Error "Failed to create secret in AWS Secrets Manager"
            exit 1
        }
    } catch {
        Write-Error "Error creating secret: $_"
        exit 1
    }
}

# Function for port-forward and HTTP test
function Test-Service {
    param(
        [string]$Service,
        [int]$LocalPort,
        [int]$RemotePort,
        [string]$Path = "/",
        [string]$Expected = "",
        [string]$Description = ""
    )
    Write-Host "Testing $Description..." -ForegroundColor Cyan
    $job = Start-Job -ScriptBlock { param($svc, $lport, $rport) kubectl port-forward "svc/$svc" "$lport`:$rport" } -ArgumentList $Service, $LocalPort, $RemotePort
    Start-Sleep -Seconds 10
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$LocalPort$Path" -UseBasicParsing -TimeoutSec 10
        if ($response.Content -match $Expected) {
            Write-Host "✓ $Description working" -ForegroundColor Green
        } else {
            Write-Host "✗ $Description did not return expected result" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Failed to access $Description" -ForegroundColor Red
    }
    Stop-Job $job -Force | Out-Null
    Remove-Job $job | Out-Null
    Start-Sleep -Seconds 2
}

# Function to validate requirements
function Test-Requirements {
    Write-Host ""
    Write-Log "🔍 Validating Requirements"
    Write-Host "=========================" -ForegroundColor Gray
    
    $requirements = @{
        'AWS CLI' = @{
            Test = { try { aws sts get-caller-identity | Out-Null; return $true } catch { return $false } }
            Install = 'https://aws.amazon.com/cli/'
            Description = 'AWS Command Line Interface'
        }
        'Terraform' = @{
            Test = { Test-Command 'terraform' }
            Install = 'https://developer.hashicorp.com/terraform/downloads'
            Description = 'Terraform - Infrastructure as Code'
        }
        'kubectl' = @{
            Test = { Test-Command 'kubectl' }
            Install = 'https://kubernetes.io/docs/tasks/tools/install-kubectl/'
            Description = 'kubectl command-line tool for Kubernetes'
        }
        'helm' = @{
            Test = { Test-Command 'helm' }
            Install = 'https://helm.sh/docs/intro/install/'
            Description = 'Helm - The Kubernetes Package Manager'
        }
        'Docker' = @{
            Test = { try { docker info | Out-Null; return $true } catch { return $false } }
            Install = 'https://www.docker.com/products/docker-desktop/'
            Description = 'Docker Desktop must be installed and running'
        }
    }
    
    $allRequirementsMet = $true
    
    foreach ($requirement in $requirements.GetEnumerator()) {
        $name = $requirement.Key
        $config = $requirement.Value
        
        Write-Log "Checking $name..."
        
        if (& $config.Test) {
            Write-Success "$name is available"
        } else {
            Write-Error "$name is not available"
            Write-Host "  Description: $($config.Description)" -ForegroundColor Gray
            Write-Host "  Install from: $($config.Install)" -ForegroundColor Gray
            $allRequirementsMet = $false
        }
    }
    
    if (-not $allRequirementsMet) {
        Write-Host ""
        Write-Error "Some requirements are missing!"
        Write-Host "Please install the missing requirements and try again." -ForegroundColor Red
        Write-Host "You can find installation instructions at the URLs provided above." -ForegroundColor Gray
        exit 1
    }
    
    Write-Host ""
    Write-Success "All requirements are met!"
}

# Function to build and push Docker images
function Build-And-Push-Images {
    param([string]$Region, [string]$Account_Id)
    
    Write-Host ""
    Write-Log "Building and Pushing Docker Images"
    Write-Host "====================================" -ForegroundColor Gray
    
    # Get ECR repository URLs from Terraform output
    Push-Location infrastructure/terraform
    try {
        $backendRepoUrl = terraform output -raw backend_ecr_repository_url
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to get ECR repository URLs from Terraform output"
            exit 1
        }
        Write-Success "Retrieved ECR repository URLs from Terraform"
    } finally {
        Pop-Location
    }
    
    # Verify AWS credentials and permissions
    Write-Log "Verifying AWS credentials and ECR permissions..."
    
    # Test ECR permissions
    try {
        $ecrTest = aws ecr describe-repositories --region $Region 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "ECR permissions test failed: $ecrTest"
            Write-Host "Please ensure your AWS user has the following permissions:" -ForegroundColor Yellow
            Write-Host "  - ecr:GetAuthorizationToken" -ForegroundColor Gray
            Write-Host "  - ecr:BatchCheckLayerAvailability" -ForegroundColor Gray
            Write-Host "  - ecr:GetDownloadUrlForLayer" -ForegroundColor Gray
            Write-Host "  - ecr:BatchGetImage" -ForegroundColor Gray
            Write-Host "  - ecr:InitiateLayerUpload" -ForegroundColor Gray
            Write-Host "  - ecr:UploadLayerPart" -ForegroundColor Gray
            Write-Host "  - ecr:CompleteLayerUpload" -ForegroundColor Gray
            Write-Host "  - ecr:PutImage" -ForegroundColor Gray
            exit 1
        }
        Write-Success "ECR permissions verified"
    } catch {
        Write-Error "Failed to verify ECR permissions: $_"
        exit 1
    }
    
    # Get ECR login token with increased timeout and retry logic
    Write-Log "Logging into ECR (with retry logic)..."
    $maxRetries = 3
    $retryCount = 0
    $loginSuccess = $false
    
    do {
        $retryCount++
        Write-Host "Attempt $retryCount/$maxRetries..." -ForegroundColor Gray
        
        try {
            # Set longer timeout for ECR login
            $env:AWS_CLI_TIMEOUT = "60"
            
            # Get ECR authorization token
            $authToken = aws ecr get-login-password --region $Region --output text
            if ($LASTEXITCODE -eq 0) {
                # Login to Docker with the token
                #$authToken | docker login --username AWS --password-stdin "$Account_Id.dkr.ecr.$Region.amazonaws.com"
                # this had to be done in cmd due to powershell issues with the token
                cmd.exe /c "aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $Account_Id.dkr.ecr.$Region.amazonaws.com"
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Logged into ECR successfully"
                    $loginSuccess = $true
                    break
                } else {
                    Write-Warning "Docker login failed, retrying..."
                }
            } else {
                Write-Warning "Failed to get ECR authorization token, retrying..."
            }
        } catch {
            Write-Warning "ECR login attempt $retryCount failed: $_"
        }
        
        if ($retryCount -lt $maxRetries) {
            Write-Host "Waiting 10 seconds before retry..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
        }
    } while ($retryCount -lt $maxRetries)
    
    if (-not $loginSuccess) {
        Write-Error "Failed to login to ECR after $maxRetries attempts"
        Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
        Write-Host "1. Verify AWS credentials: aws sts get-caller-identity" -ForegroundColor Gray
        Write-Host "2. Check ECR repository exists: aws ecr describe-repositories --region $Region" -ForegroundColor Gray
        Write-Host "3. Verify network connectivity to ECR endpoint" -ForegroundColor Gray
        Write-Host "4. Check if Docker is running and accessible" -ForegroundColor Gray
        exit 1
    }
    
    # Build and push backend image
    Write-Log "Building backend image..."
    Push-Location backend
    try {
        docker build -t backend:latest .
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Backend image built locally"
            
            # Tag and push to ECR with retry logic
            Write-Log "Tagging and pushing backend image to ECR..."
            docker tag backend:latest $backendRepoUrl":latest"
            
            $pushRetries = 3
            $pushSuccess = $false
            
            for ($i = 1; $i -le $pushRetries; $i++) {
                Write-Host "Push attempt $i/$pushRetries..." -ForegroundColor Gray
                docker push $backendRepoUrl":latest"
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Backend image pushed to ECR successfully"
                    $pushSuccess = $true
                    break
                } else {
                    Write-Warning "Push attempt $i failed, retrying..."
                    if ($i -lt $pushRetries) {
                        Start-Sleep -Seconds 15
                    }
                }
            }
            
            if (-not $pushSuccess) {
                Write-Error "Failed to push backend image to ECR after $pushRetries attempts"
                exit 1
            }
        } else {
            Write-Error "Failed to build backend image"
            exit 1
        }
    } finally {
        Pop-Location
    }
}

# Function to deploy infrastructure with Terraform
function Deploy-Infrastructure {
    param([string]$Region)
    
    Write-Host ""
    Write-Log "Deploying AWS Infrastructure with Terraform"
    Write-Host "=============================================" -ForegroundColor Gray
    
    # Navigate to terraform directory
    Push-Location infrastructure/terraform
    
    try {
        # Initialize Terraform
        Write-Log "Initializing Terraform..."
        terraform init
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to initialize Terraform"
            exit 1
        }
        Write-Success "Terraform initialized"
        
        # Set region variable
        Write-Log "Setting Terraform variables..."
        terraform workspace new $Region 2>$null
        terraform workspace select $Region
        
        # Plan Terraform
        Write-Log "Planning Terraform deployment..."
        terraform plan -var="aws_region=$Region" -out=tfplan
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to plan Terraform deployment"
            exit 1
        }
        Write-Success "Terraform plan created"
        
        # Apply Terraform
        Write-Log "Applying Terraform deployment..."
        terraform apply tfplan
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to apply Terraform deployment"
            exit 1
        }
        Write-Success "AWS infrastructure deployed successfully"
        
        # Get cluster name from Terraform output
        $clusterName = terraform output -raw eks_cluster_name
        if ($LASTEXITCODE -eq 0) {
            Write-Success "EKS Cluster created: $clusterName"
            return $clusterName
        } else {
            Write-Error "Failed to get EKS cluster name from Terraform output"
            exit 1
        }
    } finally {
        Pop-Location
    }
}

# Main script execution
Write-Host "=== Cloud Test for the TII IoT Assessment ===" -ForegroundColor Green

# Validate all requirements first
Test-Requirements

# Get AWS account ID
Write-Log "Getting AWS Account ID..."
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get AWS Account ID. Please ensure AWS CLI is configured."
    exit 1
}
Write-Success "AWS Account ID: $ACCOUNT_ID"

# Select AWS region
$REGION = Select-AWSRegion

Write-Host ""
Write-Log "Configuration Summary"
Write-Host "====================" -ForegroundColor Gray
Write-Host "AWS Account: $ACCOUNT_ID" -ForegroundColor Cyan
Write-Host "Region: $REGION" -ForegroundColor Cyan

# Initialize AWS Secrets Manager
$secretName = Initialize-AWSSecrets -Region $REGION -AccountId $ACCOUNT_ID

# Deploy infrastructure with Terraform
$CLUSTER_NAME = Deploy-Infrastructure -Region $REGION

# Build and push Docker images (after Terraform creates ECR repositories)
Build-And-Push-Images -Region $REGION -AccountId $ACCOUNT_ID

Write-Host ""
Write-Log "Configuration Summary"
Write-Host "====================" -ForegroundColor Gray
Write-Host "AWS Account: $ACCOUNT_ID" -ForegroundColor Cyan
Write-Host "Region: $REGION" -ForegroundColor Cyan
Write-Host "Cluster: $CLUSTER_NAME" -ForegroundColor Cyan

# 1. Configure kubectl for EKS cluster
Write-Host "Configuring kubectl for EKS cluster..." -ForegroundColor Yellow
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error configuring kubectl for EKS cluster"
    exit 1
}

# 2. Check if cluster is ready
Write-Log "Checking if cluster is ready..."
$maxAttempts = 30
$attempt = 0
do {
    $attempt++
    Write-Host "Attempt $attempt/$maxAttempts..." -ForegroundColor Gray
    # ATENTION! in this step, the user needs to be added to the access entry in the cluster MANUALLY

    $nodes = kubectl get nodes --no-headers 2>$null
    if ($nodes -and ($nodes | Where-Object { $_ -match "Ready" }).Count -gt 0) {
        Write-Success "Cluster is ready"
        break
    }
    if ($attempt -eq $maxAttempts) {
        Write-Error "Timeout waiting for cluster to be ready"
        exit 1
    }
    Start-Sleep -Seconds 10
} while ($true)

# 3. Update values-cloud.yaml with correct AWS account and region
Write-Log "Updating Helm configuration..."
$valuesContent = Get-Content "chart/values-cloud.yaml" -Raw
$valuesContent = $valuesContent -replace '<account-id>', $ACCOUNT_ID
$valuesContent = $valuesContent -replace '<region>', $REGION

# Get IoT Core endpoint from Terraform output
Push-Location infrastructure/terraform
try {
    $iotEndpoint = terraform output -raw iot_core_endpoint
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to get IoT Core endpoint from Terraform output"
        exit 1
    }
    Write-Success "Retrieved IoT Core endpoint: $iotEndpoint"
    
    # Get RDS endpoint from Terraform output
    $rdsEndpointWithPort = terraform output -raw rds_endpoint
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to get RDS endpoint from Terraform output"
        exit 1
    }
    
    # Remove port from endpoint (e.g., "host:5432" -> "host")
    $rdsEndpoint = $rdsEndpointWithPort -replace ':\d+$', ''
    Write-Success "Retrieved RDS endpoint: $rdsEndpoint (removed port from: $rdsEndpointWithPort)"
} finally {
    Pop-Location
}

$valuesContent = $valuesContent -replace '<iot-endpoint>', $iotEndpoint
$valuesContent = $valuesContent -replace '<rds-endpoint>', $rdsEndpoint

# Get IAM role ARN from Terraform output
$iamRoleArn = terraform output -raw backend_iam_role_arn
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get IAM role ARN from Terraform output"
    exit 1
}
Write-Success "Retrieved IAM role ARN: $iamRoleArn"

$valuesContent = $valuesContent -replace 'arn:aws:iam::<account-id>:role/eks-backend-sa-role', $iamRoleArn

# Save a temporary file with the updated values
$valuesContent | Set-Content "chart/values-cloud-temp.yaml"
Write-Success "Configuration updated with account-id: $ACCOUNT_ID, region: $REGION, IoT endpoint: $iotEndpoint, and RDS endpoint: $rdsEndpoint"

# 3.5. Install External Secrets Operator
Write-Log "Installing External Secrets Operator..."
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install external-secrets external-secrets/external-secrets --namespace external-secrets --create-namespace --wait --timeout=10m
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error installing External Secrets Operator"
    exit 1
}
Write-Success "External Secrets Operator installed successfully"

# 4. Install/update Helm chart
Write-Log "Installing/updating application via Helm..."
helm upgrade --install tii-assessment-cloud chart/ -f chart/values-cloud-temp.yaml --wait --timeout=10m
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error installing/updating Helm chart"
    exit 1
}
Write-Success "Helm chart installed/updated successfully"

# 5. Wait for pods to be ready
Write-Log "Waiting for pods to be ready..."
$maxAttempts = 30
$attempt = 0
do {
    $attempt++
    Write-Host "Attempt $attempt/$maxAttempts..." -ForegroundColor Gray
    
    $pods = kubectl get pods --no-headers 2>$null
    $readyPods = $pods | Where-Object { $_ -match "Running" -and $_ -notmatch "0/1" -and $_ -notmatch "0/2" }
    $totalPods = ($pods | Measure-Object).Count
    
    if ($readyPods -and ($readyPods | Measure-Object).Count -eq $totalPods) {
        Write-Success "All pods are ready"
        break
    }
    
    if ($attempt -eq $maxAttempts) {
        Write-Error "Timeout waiting for pods to be ready"
        Write-Host "Current pod status:" -ForegroundColor Yellow
        kubectl get pods
        exit 1
    }
    
    Start-Sleep -Seconds 10
} while ($true)

# 6. Check final status
Write-Log "Checking final status..."
Write-Host "`nPods:" -ForegroundColor Cyan
kubectl get pods

Write-Host "`nServices:" -ForegroundColor Cyan
kubectl get services

Write-Host "`nSecrets:" -ForegroundColor Cyan
kubectl get secrets

Write-Host "`nExternalSecrets:" -ForegroundColor Cyan
kubectl get externalsecrets

# 7. Automatic service access tests
Write-Log "Testing service access..."

# Test 1: Backend - metrics
Test-Service -Service "backend" -LocalPort 3000 -RemotePort 3000 -Path "/metrics" -Expected "mqtt_messages_total" -Description "Backend Metrics"

# Test 2: Prometheus
Test-Service -Service "prometheus" -LocalPort 9090 -RemotePort 9090 -Path "/api/v1/targets" -Expected "UP" -Description "Prometheus"

# Test 3: Grafana
Test-Service -Service "grafana" -LocalPort 3001 -RemotePort 3000 -Path "/api/health" -Expected "ok" -Description "Grafana"

Write-Host "`n=== Automatic tests completed ===" -ForegroundColor Green
Write-Host "`n=== Cloud Test Completed Successfully! ===" -ForegroundColor Green
Write-Host "Application is running on EKS cluster" -ForegroundColor Green
Write-Host "Database password is securely stored in AWS Secrets Manager: $secretName" -ForegroundColor Cyan
Write-Host "To access Grafana, use the external LoadBalancer" -ForegroundColor Cyan 