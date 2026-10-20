#!/bin/bash
set -euo pipefail

ENV="${1:-development}"
OVERLAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/overlays/${ENV}"

if [ ! -d "$OVERLAY_DIR" ]; then
    echo "Error: Overlay directory $OVERLAY_DIR does not exist."
    echo "Available environments: development, staging, production"
    exit 1
fi

echo "=========================================================="
echo "   Deploying Selaras SIMRS to Kubernetes (${ENV})         "
echo "=========================================================="

echo "--> Applying Kustomize overlay: ${OVERLAY_DIR}"
kubectl apply -k "$OVERLAY_DIR"

echo "--> Waiting for PostgreSQL and RabbitMQ readiness..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgres -n selaras --timeout=120s || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=rabbitmq -n selaras --timeout=120s || true

echo "--> Current Pod status in 'selaras' namespace:"
kubectl get pods -n selaras -o wide

echo "--> Deployment finished successfully!"
