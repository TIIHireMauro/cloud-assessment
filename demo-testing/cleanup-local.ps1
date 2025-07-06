#Requires -Version 5.1

# Navigate to the project root directory
Push-Location ..

Write-Host "🧹 Cleaning Local Environment - TII IoT Assessment (Kind)" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

# Logging functions
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

# Uninstall Helm chart
Write-Log "Uninstalling Helm chart..."
helm uninstall tii-assessment 2>$null
Write-Success "Helm chart uninstalled"

# Remove secrets
Write-Log "Removing secrets..."
kubectl delete secret db-secret 2>$null
Write-Success "Secrets removed"

# Stop kind cluster (optional)
Write-Host ""
$stopCluster = Read-Host "Do you want to stop the kind cluster as well? (y/N)"
if ($stopCluster -match "^[Yy]$") {
    Write-Log "Stopping kind cluster..."
    kind delete cluster --name iot-local
    Write-Success "Kind cluster stopped"
} else {
    Write-Warning "Kind cluster kept running"
}

# Clean Docker images (optional)
Write-Host ""
$removeImages = Read-Host "Do you want to remove the created Docker images? (y/N)"
if ($removeImages -match "^[Yy]$") {
    Write-Log "Removing Docker images..."
    docker rmi backend:latest simulator:latest 2>$null
    Write-Success "Docker images removed"
} else {
    Write-Warning "Docker images kept"
}

# Remove .env.local file (optional)
Write-Host ""
$removeEnvFile = Read-Host "Do you want to remove the .env.local file with credentials? (y/N)"
if ($removeEnvFile -match "^[Yy]$") {
    Write-Log "Removing .env.local file..."
    if (Test-Path ".env.local") {
        Remove-Item ".env.local" -Force
        Write-Success ".env.local file removed"
    } else {
        Write-Warning ".env.local file not found"
    }
} else {
    Write-Warning ".env.local file kept (credentials preserved)"
}

Write-Host ""
Write-Success "Cleanup completed!"

# Return to original directory
Pop-Location 