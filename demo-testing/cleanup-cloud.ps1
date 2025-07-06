# Cloud Cleanup - TII IoT Assessment (AWS) - PowerShell Version
Write-Host "🗑️ Starting Cloud Cleanup - TII IoT Assessment (AWS)" -ForegroundColor Blue
Write-Host "===================================================" -ForegroundColor Blue

# Logging function
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

# Check if AWS CLI is configured
Write-Log "Checking AWS CLI..."
try {
    $caller = aws sts get-caller-identity 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "AWS CLI is configured"
    } else {
        Write-Error "AWS CLI is not configured. Configure your AWS credentials first."
        exit 1
    }
} catch {
    Write-Error "AWS CLI is not configured. Configure your AWS credentials first."
    exit 1
}

# Check if Terraform is installed
Write-Log "Checking Terraform..."
if (Get-Command terraform -ErrorAction SilentlyContinue) {
    Write-Success "Terraform is installed"
} else {
    Write-Error "Terraform is not installed. Install Terraform first."
    exit 1
}

Write-Host ""
Write-Log "🔍 Step 1: Getting environment information"
Write-Host "------------------------------------------" -ForegroundColor Blue

Set-Location infrastructure/terraform

# Get required outputs
Write-Log "Getting Terraform outputs..."
try {
    $EKS_CLUSTER_NAME = terraform output -raw eks_cluster_name 2>$null
    $ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
    $REGION = "eu-west-1"
} catch {
    $EKS_CLUSTER_NAME = ""
    $ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
    $REGION = "eu-west-1"
}

if ([string]::IsNullOrEmpty($EKS_CLUSTER_NAME)) {
    Write-Warning "EKS cluster not found. Skipping Kubernetes cleanup."
    $SKIP_K8S = $true
} else {
    Write-Success "EKS Cluster found: $EKS_CLUSTER_NAME"
    $SKIP_K8S = $false
}

Set-Location ../..

Write-Host ""
Write-Log "🗑️ Step 2: Removing Helm application"
Write-Host "-----------------------------------" -ForegroundColor Blue

if (-not $SKIP_K8S) {
    # Configure kubectl for EKS
    Write-Log "Configuring kubectl for EKS..."
    aws eks update-kubeconfig --region $REGION --name $EKS_CLUSTER_NAME
    
    # Remove Helm application
    Write-Log "Removing Helm application..."
    helm uninstall tii-assessment-cloud --timeout=5m
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Helm application removed"
    } else {
        Write-Warning "Failed to remove Helm application (may have already been removed)"
    }
} else {
    Write-Warning "Skipping Helm application removal (EKS not found)"
}

Write-Host ""
Write-Log "🗑️ Step 3: Removing ECR images and repositories"
Write-Host "-----------------------------------------------" -ForegroundColor Blue

# Remove ECR images
Write-Log "Removing ECR images..."
aws ecr batch-delete-image --repository-name backend --image-ids imageTag=latest --region $REGION 2>$null
aws ecr batch-delete-image --repository-name simulator --image-ids imageTag=latest --region $REGION 2>$null
Write-Success "ECR images removed"

# Note: ECR repositories will be removed by Terraform destroy
Write-Log "ECR repositories will be removed by Terraform destroy"

Write-Host ""
Write-Log "🔐 Step 4: Removing AWS Secrets Manager secrets"
Write-Host "-----------------------------------------------" -ForegroundColor Blue

# Remove AWS Secrets Manager secret
Write-Log "Removing AWS Secrets Manager secret..."
$secretName = "tii-assessment/db-password"
try {
    aws secretsmanager delete-secret --secret-id $secretName --force-delete-without-recovery --region $REGION 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "AWS Secrets Manager secret removed"
    } else {
        Write-Warning "Secret may not exist or already be deleted"
    }
} catch {
    Write-Warning "Failed to remove secret (may not exist)"
}

Write-Host ""
Write-Log "🏗️ Step 5: Removing AWS infrastructure"
Write-Host "--------------------------------------" -ForegroundColor Blue

Set-Location infrastructure/terraform

# Destroy infrastructure
Write-Log "Destroying AWS infrastructure..."
terraform destroy -auto-approve
if ($LASTEXITCODE -eq 0) {
    Write-Success "AWS infrastructure removed successfully"
} else {
    Write-Error "Failed to remove AWS infrastructure"
    exit 1
}

Set-Location ../..

Write-Host ""
Write-Log "🧹 Step 6: Cleaning temporary files"
Write-Host "----------------------------------" -ForegroundColor Blue

# Remove sed backup files
Write-Log "Removing backup files..."
if (Test-Path "chart/values-cloud.yaml.bak") {
    Remove-Item "chart/values-cloud.yaml.bak"
    Write-Success "Backup files removed"
} else {
    Write-Success "No backup files found"
}

# Remove Lambda output file if it exists
Write-Log "Removing temporary files..."
if (Test-Path "/tmp/lambda_output.json") {
    Remove-Item "/tmp/lambda_output.json"
    Write-Success "Temporary files removed"
} else {
    Write-Success "No temporary files found"
}

Write-Host ""
Write-Log "✅ Cleanup completed!"
Write-Host "===================" -ForegroundColor Blue

Write-Success "🎉 Cloud environment cleaned successfully!"
Write-Host ""
Write-Host "📋 Cleanup summary:" -ForegroundColor Green
Write-Host "  ✅ Helm application removed"
Write-Host "  ✅ ECR images removed"
Write-Host "  ✅ AWS Secrets Manager secret removed"
Write-Host "  ✅ AWS infrastructure destroyed"
Write-Host "  ✅ Temporary files cleaned"
Write-Host ""
Write-Host "💡 Tip: To verify everything was removed, you can:" -ForegroundColor Green
Write-Host "  - Check AWS console if resources were removed"
Write-Host "  - Run 'aws eks list-clusters' to check EKS"
Write-Host "  - Run 'aws ecr describe-repositories' to check ECR"
Write-Host "  - Run 'aws secretsmanager list-secrets' to check Secrets Manager" 