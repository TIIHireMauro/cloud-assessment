# This script is used to test/demo the local environment of the TII IoT Assessment
# It will:
# - build the Docker images
# - create a .env.local file with secure credentials for demo purposes
# - create a kind cluster
# - deploy the Helm chart
# - run some tests
#
# Requirements: (will be checked/installed if not present)
# - Docker Desktop
# - kind
# - helm
# - kubectl

# Navigate to the project root directory
# Push-Location ..

Write-Host 'Starting Local Tests - TII IoT Assessment (Kind)' -ForegroundColor Cyan
Write-Host '=================================================' -ForegroundColor Cyan

# Logging functions
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'HH:mm:ss'
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

# Function to validate requirements
function Test-Requirements {
    Write-Host ''
    Write-Log '🔍 Validating Requirements'
    Write-Host '=========================' -ForegroundColor Gray
    
    $requirements = @{
        'Docker Desktop' = @{
            Test = { try { docker info | Out-Null; return $true } catch { return $false } }
            Install = 'https://www.docker.com/products/docker-desktop/'
            Description = 'Docker Desktop must be installed and running'
        }
        'kubectl' = @{
            Test = { Test-Command 'kubectl' }
            Install = 'https://kubernetes.io/docs/tasks/tools/install-kubectl/'
            Description = 'kubectl command-line tool for Kubernetes'
        }
        'kind' = @{
            Test = { Test-Command 'kind' }
            Install = 'https://kind.sigs.k8s.io/docs/user/quick-start/#installation'
            Description = 'kind - Kubernetes IN Docker'
        }
        'helm' = @{
            Test = { Test-Command 'helm' }
            Install = 'https://helm.sh/docs/intro/install/'
            Description = 'Helm - The Kubernetes Package Manager'
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
        Write-Host ''
        Write-Error 'Some requirements are missing!'
        Write-Host 'Please install the missing requirements and try again.' -ForegroundColor Red
        Write-Host 'You can find installation instructions at the URLs provided above.' -ForegroundColor Gray
        exit 1
    }
    
    Write-Host ''
    Write-Success 'All requirements are met!'
}

# Function to generate random password
function New-RandomPassword {
    param([int]$Length = 16)
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    $password = ""
    for ($i = 0; $i -lt $Length; $i++) {
        $password += $chars[(Get-Random -Maximum $chars.Length)]
    }
    return $password
}

# Function to load or create local environment variables
function Initialize-LocalEnvironment {
    $envFile = ".env.local"
    
    if (Test-Path $envFile) {
        Write-Log "Loading existing .env.local file..."
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') {
                [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
            }
        }
        Write-Success "Environment variables loaded from .env.local"
    } else {
        Write-Log "Creating new .env.local file with secure credentials..."
        $dbPassword = New-RandomPassword -Length 20
        
        $envContent = @"
# Local Development Environment Variables
# This file contains sensitive information and should not be committed to version control
# Generated automatically by test-local.ps1

DB_PASSWORD=$dbPassword
"@
        
        $envContent | Out-File -FilePath $envFile -Encoding UTF8
        Write-Success "Created .env.local with secure credentials"
        
        # Load the variables into current session
        [Environment]::SetEnvironmentVariable("DB_PASSWORD", $dbPassword, "Process")
    }
}

# Validate all requirements first
Test-Requirements

# Initialize local environment
Initialize-LocalEnvironment

# Check if kind cluster is running
Write-Log 'Checking kind cluster...'
$clusters = kind get clusters 2>$null
if ($clusters -match 'iot-local') {
    Write-Success 'Kind cluster already exists'
} else {
    Write-Warning 'Kind cluster not found. Creating...'
    
    $kindConfig = @'
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
'@
    
    $kindConfig | kind create cluster --name iot-local --config -
    Write-Success 'Kind cluster created'
}

Write-Host ''
Write-Log 'Step 1: Building Docker Images'
Write-Host '--------------------------------' -ForegroundColor Gray

# Build backend image
Write-Log 'Building backend image...'
Push-Location backend
try {
    docker build -t backend:latest .
    if ($LASTEXITCODE -eq 0) {
        Write-Success 'Backend image:latest built'
    } else {
        Write-Error 'Failed to build backend image'
        exit 1
    }
} finally {
    Pop-Location
}

# Build simulator image
Write-Log 'Building simulator image...'
Push-Location simulator
try {
    docker build -t simulator:latest .
    if ($LASTEXITCODE -eq 0) {
        Write-Success 'Simulator image:latest built'
    } else {
        Write-Error 'Failed to build simulator image'
        exit 1
    }
} finally {
    Pop-Location
}

# Load images into kind
Write-Log 'Loading images into kind cluster...'
kind load docker-image backend:latest --name iot-local
kind load docker-image simulator:latest --name iot-local
Write-Success 'Images loaded into kind cluster'

Write-Host ''
Write-Log 'Step 2: Creating Database Secret'
Write-Host '----------------------------------' -ForegroundColor Gray

# Create secret for PostgreSQL password using environment variable
kubectl config use-context kind-iot-local
$dbPassword = [Environment]::GetEnvironmentVariable("DB_PASSWORD")
if (-not $dbPassword) {
    Write-Error "DB_PASSWORD environment variable not found. Check .env.local file."
    exit 1
}

kubectl create secret generic db-secret --from-literal=DB_PASSWORD=$dbPassword --dry-run=client -o yaml | kubectl apply -f -
Write-Success 'Database secret created with secure password'

Write-Host ''
Write-Log 'Step 3: Deploying Application with Helm'
Write-Host '------------------------------------------' -ForegroundColor Gray

# Install/update the chart
Write-Log 'Installing Helm chart...'
helm upgrade --install tii-assessment ./chart --values ./chart/values-local.yaml --wait --timeout=5m

if ($LASTEXITCODE -eq 0) {
    Write-Success 'Helm chart installed successfully'
} else {
    Write-Error 'Failed to install Helm chart'
    exit 1
}

Write-Host ''
Write-Log 'Step 4: Checking Pod Status'
Write-Host '------------------------------' -ForegroundColor Gray

# Wait for pods to be ready
Write-Log 'Waiting for pods to be ready...'
kubectl wait --for=condition=ready pod -l app=backend --timeout=300s
kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s
kubectl wait --for=condition=ready pod -l app=mosquitto --timeout=300s
kubectl wait --for=condition=ready pod -l app=simulator --timeout=300s
kubectl wait --for=condition=ready pod -l app=prometheus --timeout=300s
kubectl wait --for=condition=ready pod -l app=grafana --timeout=300s

# Show pod status
Write-Log 'Pod status:'
kubectl get pods

Write-Host ''
Write-Log 'Step 5: Running Connectivity Tests'
Write-Host '------------------------------------' -ForegroundColor Gray

# Wait for services to be ready
Write-Log 'Waiting 30 seconds for services to be ready...'
Start-Sleep -Seconds 30

# Test 1: Backend Metrics
Write-Log 'Test 1: Checking backend metrics'
Start-Job -ScriptBlock { kubectl port-forward svc/backend 3000:3000 } | Out-Null
Start-Sleep -Seconds 5
try {
    $response = Invoke-WebRequest -Uri 'http://localhost:3000/metrics' -UseBasicParsing -ErrorAction SilentlyContinue
    if ($response.Content -match 'mqtt_messages_total') {
        Write-Success 'Metrics are being exposed'
    } else {
        Write-Error 'Metrics are not being exposed'
    }
} catch {
    Write-Error 'Could not access backend metrics'
}

# Test 2: Prometheus scraping
Write-Log 'Test 2: Checking Prometheus'
Start-Job -ScriptBlock { kubectl port-forward svc/prometheus 9090:9090 } | Out-Null
Start-Sleep -Seconds 5
try {
    $response = Invoke-WebRequest -Uri 'http://localhost:9090/api/v1/targets' -UseBasicParsing -ErrorAction SilentlyContinue
    if ($response.Content -match 'UP') {
        Write-Success 'Prometheus is working'
    } else {
        Write-Error 'Prometheus is not working'
    }
} catch {
    Write-Error 'Could not access Prometheus'
}

# Test 3: Grafana
Write-Log 'Test 3: Checking Grafana'
Start-Job -ScriptBlock { kubectl port-forward svc/grafana 3001:3000 } | Out-Null
Start-Sleep -Seconds 5
try {
    $response = Invoke-WebRequest -Uri 'http://localhost:3001/api/health' -UseBasicParsing -ErrorAction SilentlyContinue
    if ($response.Content -match 'ok') {
        Write-Success 'Grafana is working'
        
        # Check if datasource is configured
        Write-Log 'Checking Prometheus datasource...'
        $dsResponse = Invoke-WebRequest -Uri 'http://localhost:3001/api/datasources' -UseBasicParsing -ErrorAction SilentlyContinue
        if ($dsResponse.Content -match 'Prometheus') {
            Write-Success 'Prometheus datasource is configured'
        } else {
            Write-Warning 'Prometheus datasource is not automatically configured'
        }
        
        # Check if dashboards exist
        Write-Log 'Checking dashboards...'
        $dashboardResponse = Invoke-WebRequest -Uri 'http://localhost:3001/api/search' -UseBasicParsing -ErrorAction SilentlyContinue
        if ($dashboardResponse.Content -match 'IoT Data Dashboard') {
            Write-Success 'IoT Dashboard is loaded'
        } else {
            Write-Warning 'IoT Dashboard was not automatically loaded'
        }
    } else {
        Write-Error 'Grafana is not working'
    }
} catch {
    Write-Error 'Could not access Grafana'
}

Write-Host ''
Write-Log 'Step 6: Checking IoT Data'
Write-Host '----------------------------' -ForegroundColor Gray

# Wait a few seconds for the simulator to generate data
Write-Log 'Waiting 15 seconds for simulator to generate data...'
Start-Sleep -Seconds 15

# Check if there's data in the database
Write-Log 'Checking data in database...'
$dbPod = kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}'
$dbResult = kubectl exec $dbPod -- psql -U tiiassessmentuser -d tiiassessmentdb -c 'SELECT COUNT(*) FROM iot_data;'

if ($dbResult -match '[1-9]') {
    Write-Success 'IoT data is being inserted into database'
} else {
    Write-Warning 'No IoT data found yet. Wait a few more seconds.'
}

# Check data via API
try {
    $apiResponse = Invoke-WebRequest -Uri 'http://localhost:3000/api/data' -UseBasicParsing -ErrorAction SilentlyContinue
    $data = $apiResponse.Content | ConvertFrom-Json
    if ($data.Count -gt 0) {
        Write-Success 'REST API is returning data'
    } else {
        Write-Warning 'REST API has not returned data yet'
    }
} catch {
    Write-Warning 'REST API has not returned data yet'
}

Write-Host ''
Write-Log 'Access URLs'
Write-Host '--------------' -ForegroundColor Gray
Write-Host 'Backend API:     http://localhost:3000' -ForegroundColor White
Write-Host 'Backend Health:  http://localhost:3000/api/health' -ForegroundColor White
Write-Host 'Backend Data:    http://localhost:3000/api/data' -ForegroundColor White
Write-Host 'Backend Metrics: http://localhost:3000/metrics' -ForegroundColor White
Write-Host 'Prometheus:      http://localhost:9090' -ForegroundColor White
Write-Host 'Grafana:         http://localhost:3001 (admin/admin)' -ForegroundColor White
Write-Host 'PostgreSQL:      localhost:5432' -ForegroundColor White
Write-Host 'MQTT Broker:     localhost:1883' -ForegroundColor White

Write-Host ''
Write-Log 'Useful Commands'
Write-Host '-----------------' -ForegroundColor Gray
Write-Host 'View backend logs:     kubectl logs -f deployment/backend' -ForegroundColor White
Write-Host 'View simulator logs:   kubectl logs -f deployment/simulator' -ForegroundColor White
Write-Host 'View Prometheus logs:  kubectl logs -f deployment/prometheus' -ForegroundColor White
Write-Host 'View Grafana logs:     kubectl logs -f deployment/grafana' -ForegroundColor White
Write-Host 'Access database:       kubectl exec -it deployment/postgres -- psql -U tiiassessmentuser -d tiiassessmentdb' -ForegroundColor White
Write-Host 'Check kind cluster:    kind get clusters' -ForegroundColor White
Write-Host 'Stop kind cluster:     kind delete cluster --name iot-local'  -ForegroundColor White

Write-Host ''
Write-Success 'Local tests completed!'
Write-Host 'Access Grafana at http://localhost:3001 (admin/admin) to view dashboards' -ForegroundColor Green
Write-Host 'Services are accessible directly via localhost (no port-forward needed)' -ForegroundColor Green

# Return to the original directory
Pop-Location 