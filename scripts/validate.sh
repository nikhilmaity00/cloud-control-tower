#!/usr/bin/env bash

set -euo pipefail

# ------------------------------------------------------------
# Cloud Deployment Control Tower
# Deployment validation wrapper
# ------------------------------------------------------------

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$PROJECT_ROOT/control_tower/control_tower_validate.py"
POLICY_FILE="$PROJECT_ROOT/control_tower/policy.yaml"
REQUIREMENTS_FILE="$PROJECT_ROOT/requirements.txt"

echo "--------------------------------"
echo "Cloud Control Tower validation"
echo "--------------------------------"

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: Python 3 is not installed."
    exit 1
fi

PYTHON="$(command -v python3)"

echo "Python       : $("$PYTHON" --version)"

if ! "$PYTHON" -c "import yaml" >/dev/null 2>&1; then
    echo "ERROR: Python dependency 'PyYAML' is not available."
    echo
    echo "Install it with:"
    echo "  python3 -m pip install -r $REQUIREMENTS_FILE"
    exit 1
fi

echo "PyYAML       : available"

if [[ ! -f "$VALIDATOR" ]]; then
    echo "ERROR: Validator not found:"
    echo "  $VALIDATOR"
    exit 2
fi

if [[ ! -f "$POLICY_FILE" ]]; then
    echo "ERROR: Policy file not found:"
    echo "  $POLICY_FILE"
    exit 2
fi

if [[ $# -ne 1 ]]; then
    echo
    echo "Usage:"
    echo "  ./scripts/validate.sh <deployment.yaml>"
    echo
    echo "Example:"
    echo "  ./scripts/validate.sh deployments/example.yaml"
    exit 2
fi

DEPLOYMENT_FILE="$1"

if [[ ! -f "$DEPLOYMENT_FILE" ]]; then
    echo "ERROR: Deployment file not found:"
    echo "  $DEPLOYMENT_FILE"
    exit 2
fi

echo "Deployment  : $DEPLOYMENT_FILE"
echo "--------------------------------"

exec "$PYTHON" "$VALIDATOR" "$DEPLOYMENT_FILE"