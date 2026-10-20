#!/bin/bash
set -euo pipefail

ENV="${1:-development}"
OVERLAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/overlays/${ENV}"

echo "Tearing down Selaras environment: ${ENV}"
kubectl delete -k "$OVERLAY_DIR"
echo "Teardown complete."
