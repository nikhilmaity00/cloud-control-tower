#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPLOYMENT_FILE="${1:-}"

echo "--------------------------------"
echo "Cloud Control Tower deployment"
echo "--------------------------------"

if [[ -z "$DEPLOYMENT_FILE" ]]; then
    echo "ERROR: Deployment file is required."
    echo
    echo "Usage:"
    echo "  ./scripts/deploy.sh <deployment.yaml>"
    exit 2
fi

if [[ ! -f "$PROJECT_ROOT/$DEPLOYMENT_FILE" ]]; then
    echo "ERROR: Deployment file not found:"
    echo "  $PROJECT_ROOT/$DEPLOYMENT_FILE"
    exit 2
fi

echo "Deployment: $DEPLOYMENT_FILE"
echo "--------------------------------"

# ------------------------------------------------------------
# 1. Bootstrap current KodeKloud Azure session
# ------------------------------------------------------------

"$PROJECT_ROOT/scripts/bootstrap.sh"

# ------------------------------------------------------------
# 2. Validate deployment policy
# ------------------------------------------------------------

"$PROJECT_ROOT/scripts/validate.sh" "$PROJECT_ROOT/$DEPLOYMENT_FILE"

# ------------------------------------------------------------
# 3. Terraform plan
# ------------------------------------------------------------

echo
echo "--------------------------------"
echo "Terraform plan"
echo "--------------------------------"

terraform \
    -chdir="$PROJECT_ROOT/terraform" \
    plan \
    -input=false \
    -var="deployment_file=../$DEPLOYMENT_FILE"

echo
echo "--------------------------------"
echo "Deployment plan completed."
echo "No infrastructure was applied."
echo "--------------------------------"
