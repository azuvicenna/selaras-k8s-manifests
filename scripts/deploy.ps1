param (
    [string]$Environment = "development",
    [switch]$BuildImages = $false
)

$validEnvs = @("development", "staging", "production")
if ($validEnvs -notcontains $Environment) {
    Write-Error "Invalid environment '$Environment'. Valid options: $($validEnvs -join ', ')"
    exit 1
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Deploying Selaras SIMRS to Kubernetes ($Environment)   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$overlayPath = Join-Path $PSScriptRoot "..\overlays\$Environment"

# 1. Check kubectl availability
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error "'kubectl' CLI not found. Please install kubectl."
    exit 1
}

# 2. Build local docker images if requested
if ($BuildImages) {
    Write-Host "`n--> Building container images from selaras-services..." -ForegroundColor Yellow
    $servicesRoot = Join-Path $PSScriptRoot "..\..\selaras-services"
    Push-Location $servicesRoot
    try {
        docker compose --profile apps build
    } finally {
        Pop-Location
    }
}

# 3. Apply manifests using Kustomize
Write-Host "`n--> Applying Kustomize overlay: $overlayPath" -ForegroundColor Green
kubectl apply -k $overlayPath

# 4. Wait for database and infrastructure
Write-Host "`n--> Waiting for PostgreSQL and RabbitMQ to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgres -n selaras --timeout=120s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=rabbitmq -n selaras --timeout=120s

# 5. Display deployed pods
Write-Host "`n--> Status of Selaras Pods:" -ForegroundColor Green
kubectl get pods -n selaras -o wide

Write-Host "`n--> Deployment completed successfully!" -ForegroundColor Cyan
