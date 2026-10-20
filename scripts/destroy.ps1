param (
    [string]$Environment = "development"
)

$overlayPath = Join-Path $PSScriptRoot "..\overlays\$Environment"
Write-Host "Tearing down Selaras environment: $Environment" -ForegroundColor Red
kubectl delete -k $overlayPath
Write-Host "Teardown complete." -ForegroundColor Green
