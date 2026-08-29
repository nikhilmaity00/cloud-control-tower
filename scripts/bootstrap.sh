#!/usr/bin/env bash

set -euo pipefail

# ------------------------------------------------------------
# Cloud Deployment Control Tower
# KodeKloud Azure session bootstrap
# ------------------------------------------------------------

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

TFVARS_FILE="$TERRAFORM_DIR/terraform.tfvars"
SESSION_FILE="$TERRAFORM_DIR/.kodekloud-session"
STATE_FILE="$TERRAFORM_DIR/terraform.tfstate"
BACKUP_STATE_FILE="$TERRAFORM_DIR/terraform.tfstate.backup"

echo "--------------------------------"
echo "Cloud Control Tower bootstrap"
echo "--------------------------------"

# ------------------------------------------------------------
# 1. Verify Azure CLI authentication
# ------------------------------------------------------------

if ! az account show >/dev/null 2>&1; then
    echo "ERROR: Azure CLI is not authenticated."
    echo
    echo "Start or reconnect your KodeKloud Azure session and try again."
    exit 1
fi

# ------------------------------------------------------------
# 2. Discover current Azure context
# ------------------------------------------------------------

subscription_id="$(az account show --query id -o tsv)"
tenant_id="$(az account show --query tenantId -o tsv)"

# ------------------------------------------------------------
# 3. Discover the KodeKloud resource group
# ------------------------------------------------------------

resource_groups="$(az group list --query "[].name" -o tsv)"

# Remove empty lines
resource_groups="$(printf '%s\n' "$resource_groups" | sed '/^$/d')"

resource_group_count="$(printf '%s\n' "$resource_groups" | wc -l | tr -d ' ')"

if [[ "$resource_group_count" -eq 0 ]]; then
    echo "ERROR: No resource group was found in the current Azure session."
    exit 1
fi

if [[ "$resource_group_count" -gt 1 ]]; then
    echo "ERROR: Multiple resource groups were found:"
    echo
    printf '%s\n' "$resource_groups" | sed 's/^/  - /'
    echo
    echo "The bootstrap script expects exactly one KodeKloud resource group."
    exit 1
fi

resource_group_name="$resource_groups"

# ------------------------------------------------------------
# 4. Display discovered environment
# ------------------------------------------------------------

echo "Subscription  : $subscription_id"
echo "Tenant        : $tenant_id"
echo "Resource Group: $resource_group_name"
echo "--------------------------------"

# ------------------------------------------------------------
# 5. Detect KodeKloud session changes
# ------------------------------------------------------------

session_changed=false

if [[ -f "$SESSION_FILE" ]]; then
    previous_resource_group="$(cat "$SESSION_FILE")"

    if [[ "$previous_resource_group" != "$resource_group_name" ]]; then
        session_changed=true

        echo "KodeKloud session change detected."
        echo
        echo "Previous RG: $previous_resource_group"
        echo "Current RG : $resource_group_name"
        echo
        echo "The existing Terraform state belongs to the previous session."
        echo "It will be removed because those resources are no longer"
        echo "accessible from the current KodeKloud session."
        echo
    fi
fi

# ------------------------------------------------------------
# 6. Reset stale Terraform state
# ------------------------------------------------------------

if [[ "$session_changed" == true ]]; then

    if [[ -f "$STATE_FILE" ]]; then
        echo "Removing stale Terraform state..."
        rm -f "$STATE_FILE"
    fi

    if [[ -f "$BACKUP_STATE_FILE" ]]; then
        echo "Removing stale Terraform state backup..."
        rm -f "$BACKUP_STATE_FILE"
    fi

    echo "Terraform state reset complete."
    echo
fi

# ------------------------------------------------------------
# 7. Generate Terraform variables
# ------------------------------------------------------------

cat > "$TFVARS_FILE" <<EOF
resource_group_name = "$resource_group_name"
subscription_id     = "$subscription_id"
EOF

# ------------------------------------------------------------
# 8. Save current KodeKloud session marker
# ------------------------------------------------------------

printf '%s\n' "$resource_group_name" > "$SESSION_FILE"

# ------------------------------------------------------------
# 9. Final status
# ------------------------------------------------------------

echo "Terraform environment configured."
echo "--------------------------------"
echo "Terraform variables:"
echo "  $TFVARS_FILE"
echo
echo "Session marker:"
echo "  $SESSION_FILE"
echo
echo "Current resource group:"
echo "  $resource_group_name"
echo
echo "Ready for Terraform."
echo "--------------------------------"